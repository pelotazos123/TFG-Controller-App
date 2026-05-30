import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/transport/transport_message.dart';

abstract class ControlTransport {
  bool get isConnected;
  Stream<TransportEvent> get terminalEvents;

  Future<void> connect();
  void disconnect();
  void send({required double tx, required double ty, required double sx, required double sy});
  Future<void> sendTerminalCommand(String command);
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
