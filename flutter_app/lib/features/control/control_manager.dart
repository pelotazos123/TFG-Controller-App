import 'dart:async';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/ble_transport.dart';
import 'package:flutter_rccontroller_app/transport/transport_message.dart';
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

class ControlOutput {
  const ControlOutput({
    required this.tx,
    required this.sy,
    required this.sx,
  });

  final double tx;
  final double sy;
  final double sx;
}

class ControlManager extends ChangeNotifier {
  ControlManager._();

  static final ControlManager instance = ControlManager._();

  ControlTransport? _transport;
  Timer? _sendTimer;
  bool _lastKnownConnected = false;
  bool _isConnecting = false;
  int _lastSendMs = 0;
  int _currentTickMs = 0;
  bool _lastInputActive = false;
  final Stopwatch _sendStopwatch = Stopwatch()..start();
  StreamSubscription<TransportEvent>? _terminalSub;
  final List<TransportEvent> _terminalHistory = [];

  static const int _terminalHistoryLimit = 200;

  static const int _activeSendIntervalMs = 33;
  static const int _idleSendIntervalMs = 200;
  static const double _inputEpsilon = 0.001;

  double _driveScale = 1.0;

  bool _reverseSteering = false;
  bool _reverseThrottle = false;
  double _tx = 0.0;
  double _ty = 0.0;
  double _sx = 0.0;
  MotionCommand? _activeMotion;
  double _activeMotionPower = 1.0;

  ControlTransport? get transport => _transport;
  List<TransportEvent> get terminalHistory => List.unmodifiable(_terminalHistory);

  double get driveScale => _driveScale;

  bool get reverseSteering => _reverseSteering;
  bool get reverseThrottle => _reverseThrottle;
  bool get isConnecting => _isConnecting;

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
    final previous = _transport;
    if (previous != null && previous != transport) {
      previous.disconnect();
    }
    _terminalSub?.cancel();
    _terminalSub = null;
    _stopTimer();
    _lastSendMs = 0;
    _lastInputActive = false;
    _isConnecting = false;
    _transport = transport;
    _lastKnownConnected = transport.isConnected;
    _terminalSub = transport.terminalEvents.listen(_recordTerminalEvent);
    notifyListeners();
  }

  Future<void> connect() async {
    final current = _transport;
    if (current == null) return;
    _setConnecting(true);
    try {
      await current.connect();
      _lastKnownConnected = current.isConnected;
      _startTimer();
    } finally {
      _setConnecting(false);
    }
  }

  void disconnect() {
    _stopTimer();
    _terminalSub?.cancel();
    _terminalSub = null;
    _transport?.disconnect();
    _lastKnownConnected = false;
    _lastSendMs = 0;
    _lastInputActive = false;
    _activeMotion = null;
    _isConnecting = false;
    notifyListeners();
  }

  void pauseSending() {
    _stopTimer();
    _lastSendMs = 0;
    _lastInputActive = false;
  }

  void _setConnecting(bool value) {
    if (_isConnecting == value) return;
    _isConnecting = value;
    notifyListeners();
  }

  void sendJoystick(double tx, double ty, double sx) {
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
    if (direction == null) {
      _tx = 0.0;
      _ty = 0.0;
      _sx = 0.0;
    }
    _activeMotion = direction;
    _activeMotionPower = clampedPower;
    _lastSendMs = 0;
    _transmitCurrentState();
  }

  void _startTimer() {
    _restartTimer(_idleSendIntervalMs);
  }

  void _stopTimer() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _currentTickMs = 0;
  }

  void _restartTimer(int intervalMs) {
    if (_currentTickMs == intervalMs && _sendTimer != null) return;
    _sendTimer?.cancel();
    _currentTickMs = intervalMs;
    _sendTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _transmitCurrentState(),
    );
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

    final output = _resolveCurrentOutput();
    final isActiveInput = _isActiveInput(output);

    final minInterval = _minSendIntervalMs(current);
    final desiredInterval = isActiveInput
      ? _activeSendIntervalMs
      : _idleSendIntervalMs;
    final effectiveInterval = minInterval > desiredInterval
      ? minInterval
      : desiredInterval;
    _restartTimer(effectiveInterval);

    final nowMs = _sendStopwatch.elapsedMilliseconds;
    final forceSend = isActiveInput != _lastInputActive;
    if (!forceSend && nowMs - _lastSendMs < effectiveInterval) {
      _lastInputActive = isActiveInput;
      return;
    }
    _lastSendMs = nowMs;
    _lastInputActive = isActiveInput;

    current.send(tx: output.tx, ty: 0.0, sx: output.sx, sy: output.sy);
  }

  ControlOutput _resolveCurrentOutput() {
    final ControlOutput baseOutput = _activeMotion != null
      ? _resolveMotionCommandOutput(_activeMotion!, _activeMotionPower)
      : ControlOutput(tx: _tx, sy: _ty, sx: _sx);

    final withDirectionPreferences = _applyDirectionPreferences(baseOutput);
    return _applyDriveScale(withDirectionPreferences);
  }

  ControlOutput _resolveMotionCommandOutput(MotionCommand command, double power) {
    switch (command) {
      case MotionCommand.forward:
        return ControlOutput(tx: 0.0, sy: power, sx: 0.0);
      case MotionCommand.backward:
        return ControlOutput(tx: 0.0, sy: -power, sx: 0.0);
      case MotionCommand.left:
        return ControlOutput(tx: -power, sy: 0.0, sx: 0.0);
      case MotionCommand.right:
        return ControlOutput(tx: power, sy: 0.0, sx: 0.0);
      case MotionCommand.forwardLeft:
        return ControlOutput(tx: -power, sy: power, sx: 0.0);
      case MotionCommand.forwardRight:
        return ControlOutput(tx: power, sy: power, sx: 0.0);
      case MotionCommand.backwardLeft:
        return ControlOutput(tx: -power, sy: -power, sx: 0.0);
      case MotionCommand.backwardRight:
        return ControlOutput(tx: power, sy: -power, sx: 0.0);
      case MotionCommand.rotateLeft:
        return ControlOutput(tx: 0.0, sy: 0.0, sx: -power);
      case MotionCommand.rotateRight:
        return ControlOutput(tx: 0.0, sy: 0.0, sx: power);
    }
  }

  ControlOutput _applyDirectionPreferences(ControlOutput output) {
    return ControlOutput(
      tx: _reverseSteering ? -output.tx : output.tx,
      sy: _reverseThrottle ? -output.sy : output.sy,
      sx: output.sx,
    );
  }

  ControlOutput _applyDriveScale(ControlOutput output) {
    return ControlOutput(
      tx: (output.tx * _driveScale).clamp(-1.0, 1.0).toDouble(),
      sy: (output.sy * _driveScale).clamp(-1.0, 1.0).toDouble(),
      sx: (output.sx * _driveScale).clamp(-1.0, 1.0).toDouble(),
    );
  }

  bool _isActiveInput(ControlOutput output) {
    return _activeMotion != null ||
      output.tx.abs() > _inputEpsilon ||
      output.sy.abs() > _inputEpsilon ||
      output.sx.abs() > _inputEpsilon;
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
      _lastInputActive = false;
      notifyListeners();
    }
  }

  void _recordTerminalEvent(TransportEvent event) {
    _terminalHistory.add(event);
    if (_terminalHistory.length > _terminalHistoryLimit) {
      _terminalHistory.removeAt(0);
    }
  }
}
