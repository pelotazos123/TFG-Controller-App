import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter/foundation.dart';

class ControlManager extends ChangeNotifier {
  ControlManager._();

  static final ControlManager instance = ControlManager._();

  factory ControlManager() => instance;

  ControlTransport? _transport;

  ControlTransport? get transport => _transport;

  bool get isConnected => _transport?.isConnected == true;

  void setTransport(ControlTransport transport) {
    _transport = transport;
    notifyListeners();
  }

  Future<void> connect() async {
    final current = _transport;
    if (current == null) return;
    await current.connect();
    notifyListeners();
  }

  void disconnect() {
    _transport?.disconnect();
    notifyListeners();
  }

  void sendJoystick(double tx, double ty, double sx, double sy) {
    final current = _transport;
    if (current == null || !current.isConnected) return;
    current.send(tx: tx, ty: ty, sx: sx, sy: sy);
  }
}
