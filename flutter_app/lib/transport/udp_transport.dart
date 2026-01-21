import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_rccontroller_app/transport/control_transport.dart';

class UdpTransport implements ControlTransport {
  final String ip;
  final int port;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSub;
  bool _initialized = false;

  UdpTransport({required this.ip, required this.port});

  @override
  bool get isConnected => _initialized;

  @override
  Future<void> connect() async {
    if (_initialized) return;

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket = socket;

    final completer = Completer<void>();

    _socketSub = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;

        Datagram? datagram;
        while ((datagram = socket.receive()) != null) {
          final dg = datagram!;

          // Only accept responses from the target endpoint.
          if (dg.address.address != ip || dg.port != port) continue;

          final raw = utf8.decode(dg.data, allowMalformed: true);
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map && decoded['type'] == 'hello_ack') {
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

    // Application-level handshake so UDP doesn't report "connected" when the ESP32 isn't there.
    final hello = jsonEncode({'type': 'hello'});
    socket.send(utf8.encode(hello), InternetAddress(ip), port);

    try {
      await completer.future.timeout(const Duration(seconds: 10));
      _initialized = true;
    } catch (e) {
      disconnect();
      rethrow;
    }
  }

  @override
  void disconnect() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
    _initialized = false;
  }

  @override
  void send({required double tx, required double ty, required double sx, required double sy}) {
    if (!_initialized || _socket == null) return;
    final payload = jsonEncode({'tx': tx, 'ty': ty, 'sx': sx, 'sy': sy});
    _socket!.send(utf8.encode(payload), InternetAddress(ip), port);
  }
}
