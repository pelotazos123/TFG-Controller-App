import 'dart:async';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/transport/ble_transport.dart';
import 'package:flutter/foundation.dart';

enum MotionCommand {
  forward,
  backward,
  left,
  right,
  forwardLeft,
  forwardRight,
  backwardLeft,
  backwardRight,
  rotateLeft,
  rotateRight,
}

class ControlManager extends ChangeNotifier {
  ControlManager._();

  static final ControlManager instance = ControlManager._();

  ControlTransport? _transport;
  Timer? _sendTimer;
  bool _lastKnownConnected = false;
  int _lastSendMs = 0;

  double _driveScale = 1.0;

  bool _reverseSteering = false;
  bool _reverseThrottle = false;

  double _tx = 0.0;
  double _ty = 0.0;
  double _sx = 0.0;
  MotionCommand? _activeMotion;
  double _activeMotionPower = 1.0;

  GpsTelemetry? _gpsTelemetry;

  ControlTransport? get transport => _transport;

  double get driveScale => _driveScale;

  bool get reverseSteering => _reverseSteering;
  bool get reverseThrottle => _reverseThrottle;
  GpsTelemetry? get gpsTelemetry => _gpsTelemetry;

  void setDriveScale(double value) {
    final clamped = value.clamp(0.2, 1.0);
    if (_driveScale == clamped) return;
    _driveScale = clamped;
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
    _lastSendMs = 0;
    _activeMotion = null;
    _gpsTelemetry = null;
    notifyListeners();
  }

  void pauseSending() {
    _stopTimer();
    _lastSendMs = 0;
  }

  void sendJoystick(double tx, double ty, double sx, double sy) {
    _tx = tx;
    _ty = ty;
    _sx = sx;
    _transmitCurrentState();
  }

  void setMotionCommand(MotionCommand? direction, {double power = 1.0}) {
    final clampedPower = power.clamp(0.0, 1.0).toDouble();
    if (_activeMotion == direction && _activeMotionPower == clampedPower) {
      return;
    }
    _activeMotion = direction;
    _activeMotionPower = clampedPower;
    _transmitCurrentState();
  }

  void _startTimer() {
    _stopTimer();
    _sendTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final minInterval = _minSendIntervalMs(current);
    if (minInterval > 0 && nowMs - _lastSendMs < minInterval) {
      return;
    }
    _lastSendMs = nowMs;

    double outTx;
    double outSy;
    double outSx;

    if (_activeMotion != null) {
      final power = _activeMotionPower;
      switch (_activeMotion!) {
        case MotionCommand.forward:
          outTx = 0.0;
          outSy = power;
          outSx = 0.0;
          break;
        case MotionCommand.backward:
          outTx = 0.0;
          outSy = -power;
          outSx = 0.0;
          break;
        case MotionCommand.left:
          outTx = -power;
          outSy = 0.0;
          outSx = 0.0;
          break;
        case MotionCommand.right:
          outTx = power;
          outSy = 0.0;
          outSx = 0.0;
          break;
        case MotionCommand.forwardLeft:
          outTx = -power;
          outSy = power;
          outSx = 0.0;
          break;
        case MotionCommand.forwardRight:
          outTx = power;
          outSy = power;
          outSx = 0.0;
          break;
        case MotionCommand.backwardLeft:
          outTx = -power;
          outSy = -power;
          outSx = 0.0;
          break;
        case MotionCommand.backwardRight:
          outTx = power;
          outSy = -power;
          outSx = 0.0;
          break;
        case MotionCommand.rotateLeft:
          outTx = 0.0;
          outSy = 0.0;
          outSx = -power;
          break;
        case MotionCommand.rotateRight:
          outTx = 0.0;
          outSy = 0.0;
          outSx = power;
          break;
      }
    } else {
      // Omnidirectional mapping:
      // left joystick -> tx (strafe), sy (forward/backward)
      // right joystick X -> sx (rotation)
      outTx = _tx;
      outSy = _ty;
      outSx = _sx;
    }

    if (_reverseSteering) outTx = -outTx;
    if (_reverseThrottle) outSy = -outSy;

    outTx = (outTx * _driveScale).clamp(-1.0, 1.0).toDouble();
    outSy = (outSy * _driveScale).clamp(-1.0, 1.0).toDouble();
    outSx = (outSx * _driveScale).clamp(-1.0, 1.0).toDouble();

    current.send(tx: outTx, ty: 0.0, sx: outSx, sy: outSy);

    final latestGps = current.gpsTelemetry;
    if (latestGps != _gpsTelemetry) {
      _gpsTelemetry = latestGps;
      notifyListeners();
    }
  }

  int _minSendIntervalMs(ControlTransport transport) {
    if (transport is BleTransport) {
      return 40;
    }
    return 0;
  }

  void _markDisconnectedIfNeeded() {
    _stopTimer();
    if (_lastKnownConnected) {
      _lastKnownConnected = false;
      notifyListeners();
    }
  }
}
