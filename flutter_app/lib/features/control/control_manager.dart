import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter/foundation.dart';

class ControlManager extends ChangeNotifier {
  ControlManager._();

  static final ControlManager instance = ControlManager._();

  factory ControlManager() => instance;

  ControlTransport? _transport;

  double _deadZone = 0.05;

  bool _reverseSteering = false;
  bool _reverseThrottle = false;

  ControlTransport? get transport => _transport;

  double get deadZone => _deadZone;

  bool get reverseSteering => _reverseSteering;
  bool get reverseThrottle => _reverseThrottle;

  void setDeadZone(double value) {
    final clamped = value.clamp(0.0, 0.3);
    if (_deadZone == clamped) return;
    _deadZone = clamped;
    notifyListeners();
  }

  void setReverseSteering(bool value) {
    if (_reverseSteering == value) return;
    _reverseSteering = value;
    notifyListeners();
  }

  void setReverseThrottle(bool value) {
    if (_reverseThrottle == value) return;
    _reverseThrottle = value;
    notifyListeners();
  }

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

    // Steering is the left joystick (tx/ty), throttle is the right joystick (sx/sy).
    // Reverse steering flips the X axis. Reverse throttle flips the Y axis.
    final outTx = _reverseSteering ? -tx : tx;
    final outSy = _reverseThrottle ? -sy : sy;

    current.send(tx: outTx, ty: ty, sx: sx, sy: outSy);
  }
}
