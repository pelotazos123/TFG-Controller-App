import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/services/network_binding_service.dart';

class UdpTransport implements ControlTransport {
  final String ip;
  final int port;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSub;
  Timer? _healthTimer;
  bool _healthCheckInProgress = false;
  bool _initialized = false;

  InternetAddress? _targetAddress;
  int? _targetPort;

  UdpTransport({required this.ip, required this.port});

  @override
  bool get isConnected => _initialized;

  @override
  Future<void> connect() async {
    if (_initialized) return;

    await NetworkBindingService.bindToWifi();

    final configuredAddress = InternetAddress(ip);
    _targetAddress = configuredAddress;
    _targetPort = port;

    final probeAddresses = <InternetAddress>[configuredAddress];
    const apDefaultIp = '192.168.4.1';
    if (configuredAddress.type == InternetAddressType.IPv4 &&
        configuredAddress.address != apDefaultIp) {
      probeAddresses.add(InternetAddress(apDefaultIp));
    }

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket = socket;

    final completer = Completer<void>();

    _socketSub = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;

        Datagram? datagram;
        while ((datagram = socket.receive()) != null) {
          final dg = datagram!;

          final raw = utf8.decode(dg.data, allowMalformed: true);
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map && decoded['type'] == 'hello_ack') {
              // Lock endpoint to the responder so AP/STA differences in source
              // endpoint handling do not break the handshake.
              _targetAddress = dg.address;
              _targetPort = dg.port;
              if (!completer.isCompleted) completer.complete();
              return;
            }
          } catch (_) {
            // Ignore non-JSON packets.
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    final hello = jsonEncode({'type': 'hello'});
    final helloPayload = utf8.encode(hello);
    
    Timer? helloTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!completer.isCompleted) {
        for (final address in probeAddresses) {
          socket.send(helloPayload, address, port);
        }
      }
    });

    for (final address in probeAddresses) {
      socket.send(helloPayload, address, port);
    }

    try {
      await completer.future.timeout(const Duration(seconds: 5));
      _initialized = true;
      _startHealthMonitor();
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      helloTimer.cancel();
    }
  }

  @override
  void disconnect() {
    _healthTimer?.cancel();
    _healthTimer = null;
    _healthCheckInProgress = false;
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
    _initialized = false;
    _targetPort = null;
    
    unawaited(NetworkBindingService.clearBinding());
  }

  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_initialized || _healthCheckInProgress) return;

      _healthCheckInProgress = true;
      try {
        final stillBound = await NetworkBindingService.isWifiBound();
        if (!stillBound && _initialized) {
          disconnect();
        }
      } finally {
        _healthCheckInProgress = false;
      }
    });
  }

  @override
  void send({required double tx, required double ty, required double sx, required double sy}) {
    if (!_initialized ||
        _socket == null ||
        _targetAddress == null ||
        _targetPort == null) {
      return;
    }

    final payload = jsonEncode({'tx': tx, 'ty': ty, 'sx': sx, 'sy': sy});
    try {
      _socket!.send(utf8.encode(payload), _targetAddress!, _targetPort!);
    } on SocketException {
      disconnect();
    }
  }
}
