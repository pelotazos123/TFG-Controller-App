import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/services/network_binding_service.dart';
import 'package:flutter_rccontroller_app/transport/transport_message.dart';

class UdpTransport implements ControlTransport {
  final String ip;
  final int port;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSub;
  Timer? _healthTimer;
  bool _healthCheckInProgress = false;
  bool _initialized = false;
  final StreamController<TransportEvent> _terminalEvents =
      StreamController<TransportEvent>.broadcast();

  InternetAddress? _targetAddress;
  int? _targetPort;

  bool get _hasSendEndpoint =>
      _initialized &&
      _socket != null &&
      _targetAddress != null &&
      _targetPort != null;

  UdpTransport({required this.ip, required this.port});

  @override
  bool get isConnected => _initialized;


  @override
  Stream<TransportEvent> get terminalEvents => _terminalEvents.stream;

  @override
  Future<void> connect() async {
    if (_initialized) return;
    bool bound = false;

    try {
      await NetworkBindingService.bindToWifi(targetHost: ip);
      bound = true;

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

            if (dg.data.length > maxInboundPacketBytes) {
              continue;
            }

            final raw = _decodePacket(dg.data);
            if (raw == null || !_looksLikeJson(raw)) {
              continue;
            }

            try {
              final decoded = jsonDecode(raw);
              final event = parseTransportEvent(decoded);
              if (event != null) {
                if (event.type == 'hello_ack') {
                  _targetAddress = dg.address;
                  _targetPort = dg.port;
                  _terminalEvents.add(event);
                  if (!completer.isCompleted) completer.complete();
                  return;
                }

                if (event.type == 'log' || event.type == 'terminal') {
                  _terminalEvents.add(event);
                  continue;
                }
              }
            } catch (error) {
              debugPrint('UDP packet parse error: $error');
            }
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('UDP socket error: $error');
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
      } finally {
        helloTimer.cancel();
      }
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      if (!_initialized && bound) {
        unawaited(NetworkBindingService.clearBinding());
      }
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

  @override
  Future<void> sendModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {
    _sendCommandPayload({
      'type': 'set_mode',
      'mode': controllerModeToPayload(mode),
      'ssid': ?ssid,
      'pass': ?password,
    });
  }

  @override
  Future<void> sendMainModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {
    _sendCommandPayload({
      'type': 'set_main_mode',
      'mode': controllerModeToPayload(mode),
      'ssid': ?ssid,
      'pass': ?password,
    });
  }

  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_initialized || _healthCheckInProgress) return;

      _healthCheckInProgress = true;
      try {
        final stillBound = await NetworkBindingService.isWifiBound(
          targetHost: ip,
        );
        if (!stillBound && _initialized) {
          disconnect();
        }
      } finally {
        _healthCheckInProgress = false;
      }
    });
  }

  @override
  void send({required double tx, required double ty, required double sx, required double sy, required double driveScale}) {
    if (!_hasSendEndpoint) {
      return;
    }

    final payload = buildControlPayload(tx, ty, sx, sy, driveScale);
    try {
      _socket!.send(utf8.encode(payload), _targetAddress!, _targetPort!);
    } on SocketException {
      debugPrint('UDP send failed, disconnecting');
      disconnect();
    }
  }

  @override
  Future<void> sendTerminalCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    _sendRawJson(
      jsonEncode({
        'type': 'terminal',
        'command': trimmed,
      }),
    );
  }

  String? _decodePacket(List<int> data) {
    try {
      return utf8.decode(data);
    } on FormatException {
      return null;
    }
  }

  bool _looksLikeJson(String raw) {
    final trimmed = raw.trimLeft();
    return trimmed.isNotEmpty && trimmed.codeUnitAt(0) == 0x7b;
  }

  void _sendCommandPayload(Map<String, Object?> payload) {
    if (!_hasSendEndpoint) {
      return;
    }
    _sendRawJson(jsonEncode(payload));
  }

  void _sendRawJson(String payload) {
    if (!_hasSendEndpoint) {
      return;
    }
    _socket!.send(utf8.encode(payload), _targetAddress!, _targetPort!);
  }
}
