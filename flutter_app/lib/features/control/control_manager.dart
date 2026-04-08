import 'dart:async';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter/foundation.dart';

class ControlManager extends ChangeNotifier {
  ControlManager._();

  static final ControlManager instance = ControlManager._();

  ControlTransport? _transport;
  Timer? _sendTimer;
  bool _lastKnownConnected = false;

  double _deadZone = 0.05;

  bool _reverseSteering = false;
  bool _reverseThrottle = false;

  double _tx = 0.0;
  double _ty = 0.0;
  double _sx = 0.0;
  double _sy = 0.0;

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
    _lastKnownConnected = transport.isConnected;
    notifyListeners();
  }

  Future<void> connect() async {
    final current = _transport;
    if (current == null) return;
    await current.connect();
    _lastKnownConnected = current.isConnected;
    
    _startTimer();
    notifyListeners();
  }

  void disconnect() {
    _stopTimer();
    _transport?.disconnect();
    _lastKnownConnected = false;
    notifyListeners();
  }

  void sendJoystick(double tx, double ty, double sx, double sy) {
    _tx = tx;
    _ty = ty;
    _sx = sx;
    _sy = sy;
  }

  void _startTimer() {
    _stopTimer();
    _sendTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _transmitCurrentState();
    });
  }

  void _stopTimer() {
    _sendTimer?.cancel();
    _sendTimer = null;
  }

  void _transmitCurrentState() {
    final current = _transport;
    if (current == null) {
      _markDisconnectedIfNeeded();
      return;
    }

    final connected = current.isConnected;
    if (!connected) {
      _markDisconnectedIfNeeded();
      return;
    }

    if (!_lastKnownConnected) {
      _lastKnownConnected = true;
      notifyListeners();
    }

    // Steering is the left joystick (tx/ty), throttle is the right joystick (sx/sy).
    // Reverse steering flips the X axis. Reverse throttle flips the Y axis.
    final outTx = _reverseSteering ? -_tx : _tx;
    final outSy = _reverseThrottle ? -_sy : _sy;

    current.send(tx: outTx, ty: _ty, sx: _sx, sy: outSy);
  }

  void _markDisconnectedIfNeeded() {
    _stopTimer();
    if (_lastKnownConnected) {
      _lastKnownConnected = false;
      notifyListeners();
    }
  }
}
