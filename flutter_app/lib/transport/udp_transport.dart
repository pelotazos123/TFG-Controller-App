import 'dart:convert';
import 'dart:io';

import 'package:flutter_rccontroller_app/transport/control_transport.dart';

class UdpTransport implements ControlTransport {
  final String ip;
  final int port;
  RawDatagramSocket? _socket;
  bool _initialized = false;

  UdpTransport({required this.ip, required this.port});

  @override
  bool get isConnected => _initialized;

  @override
  Future<void> connect() async {
    if (_initialized) return;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _initialized = true;
  }

  @override
  void disconnect() {
    _socket?.close();
    _initialized = false;
  }

  @override
  void send({required double tx, required double ty, required double sx, required double sy}) {
    if (!_initialized || _socket == null) return;
    final payload = jsonEncode({'tx': tx, 'ty': ty, 'sx': sx, 'sy': sy});
    _socket!.send(utf8.encode(payload), InternetAddress(ip), port);
  }
}
