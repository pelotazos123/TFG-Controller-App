import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';

abstract class ControlTransport {
  bool get isConnected;
  GpsTelemetry? get gpsTelemetry;

  Future<void> connect();
  void disconnect();
  void send({required double tx, required double ty, required double sx, required double sy});
  Future<void> sendModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  });
  Future<void> sendMainModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  });
}
