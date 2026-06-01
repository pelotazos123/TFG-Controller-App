import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/features/terminal/terminal_page.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';
import 'package:flutter_rccontroller_app/transport/ble_transport.dart';
import 'package:flutter_rccontroller_app/transport/udp_transport.dart';

import '../../locale_provider.dart';
import '../../theme_provider.dart';
import '../settings/settings_page.dart';
import '../settings/settings_manager.dart';

class ControlPage extends StatefulWidget {
  final ThemeProvider? themeProvider;
  final LocaleProvider? localeProvider;

  const ControlPage({super.key, this.themeProvider, this.localeProvider});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  static const double _responseGamma = 1.35;
  static const double _motionCommandPower = 1.0;
  static const double _translationDeadzone = 0.08;
  static const double _translationAxisSnap = 0.12;

  static const _allOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const _landscapeOrientations = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  Offset _leftJoystick = Offset.zero;
  Offset _rightJoystick = Offset.zero;
  MotionCommand? _activeMotion;

  bool _isLandscapeLocked = false;
  bool _showMovementMatrix = true;

  final ControlManager _controlManager = ControlManager.instance;

  final SettingsManager _settingsManager = SettingsManager();
  int _driveWheels = 4;
  bool _mecanumWheels = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(_allOrientations);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadDriveSettings();
  }

  void _toggleMovementMatrix() {
    if (!(_driveWheels == 4 && _mecanumWheels)) {
      return;
    }
    final shouldShow = !_showMovementMatrix;
    setState(() {
      _showMovementMatrix = shouldShow;
      if (!shouldShow) {
        _activeMotion = null;
      }
    });

    if (!shouldShow) {
      _controlManager.setMotionCommand(null);
      _sendCurrentControl();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(_allOrientations);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controlManager.setMotionCommand(null);
    _controlManager.sendJoystick(0, 0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            final joystickSize = isLandscape ? 170.0 : 150.0;
            final thumbSize = isLandscape ? 52.0 : 45.0;
            final translateFactor = isLandscape ? 52.0 : 45.0;

            return Column(
              children: [
                _buildStatusBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: isLandscape
                        ? Row(
                            children: [
                              Expanded(
                                child: _buildJoystick(
                                  label: localizations?.translation ??
                                      'TRANSLATION',
                                  value: _leftJoystick,
                                  horizontalOnly: false,
                                  onChanged: (v) {
                                    _clearMotionCommand();
                                    final adjusted = _driveWheels == 2 ? Offset(0.0, v.dy) : v;
                                    setState(() => _leftJoystick = adjusted);
                                    _sendCurrentControl();
                                  },
                                  joystickSize: joystickSize,
                                  thumbSize: thumbSize,
                                  translateFactor: translateFactor,
                                ),
                              ),
                              if (_showMovementMatrix && _driveWheels == 4 && _mecanumWheels) ...[
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 340,
                                  ),
                                  child: _buildMotionPad(isLandscape: true),
                                ),
                                const SizedBox(width: 10),
                              ] else
                                const SizedBox(width: 12),
                              Expanded(
                                child: _buildJoystick(
                                  label: localizations?.rotation ?? 'ROTATION',
                                  value: _rightJoystick,
                                  horizontalOnly: true,
                                  onChanged: (v) {
                                    setState(
                                      () => _rightJoystick = Offset(v.dx, 0),
                                    );
                                    _sendCurrentControl();
                                  },
                                  joystickSize: joystickSize,
                                  thumbSize: thumbSize,
                                  translateFactor: translateFactor,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildJoystick(
                                        label: localizations?.translation ??
                                            'TRANSLATION',
                                        value: _leftJoystick,
                                        horizontalOnly: false,
                                        onChanged: (v) {
                                          _clearMotionCommand();
                                          final adjusted = _driveWheels == 2 ? Offset(0.0, v.dy) : v;
                                          setState(() => _leftJoystick = adjusted);
                                          _sendCurrentControl();
                                        },
                                        joystickSize: joystickSize,
                                        thumbSize: thumbSize,
                                        translateFactor: translateFactor,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildJoystick(
                                        label:
                                            localizations?.rotation ?? 'ROTATION',
                                        value: _rightJoystick,
                                        horizontalOnly: true,
                                        onChanged: (v) {
                                          setState(
                                            () => _rightJoystick = Offset(
                                              v.dx,
                                              0,
                                            ),
                                          );
                                          _sendCurrentControl();
                                        },
                                        joystickSize: joystickSize,
                                        thumbSize: thumbSize,
                                        translateFactor: translateFactor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_showMovementMatrix && _driveWheels == 4 && _mecanumWheels) ...[
                                _buildMotionPad(isLandscape: false),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final connectedColor = isDark ? Colors.green : Colors.green[700]!;
    final disconnectedColor = isDark ? Colors.red : Colors.red[700]!;
    final connectingColor = isDark ? Colors.orange[300]! : Colors.orange[700]!;

    return ListenableBuilder(
      listenable: _controlManager,
      builder: (context, _) {
        final isConnected = _controlManager.isConnected;
        final isConnecting = _controlManager.isConnecting;
        final transport = _controlManager.transport;
        final rotationTooltip = _isLandscapeLocked
          ? (localizations?.unlockRotation ?? 'Unlock rotation')
          : (localizations?.lockRotation ?? 'Lock rotation');

        final connectedIcon = switch (transport) {
          UdpTransport() => Icons.wifi,
          BleTransport() => Icons.bluetooth,
          _ => Icons.link,
        };
        final disconnectedIcon = switch (transport) {
          UdpTransport() => Icons.wifi_off,
          BleTransport() => Icons.bluetooth_disabled,
          _ => Icons.link_off,
        };
        final connectingIcon = switch (transport) {
          UdpTransport() => Icons.wifi_tethering,
          BleTransport() => Icons.bluetooth_searching,
          _ => Icons.sync,
        };
        final statusIcon = isConnected
            ? connectedIcon
            : (isConnecting ? connectingIcon : disconnectedIcon);
        final statusColor = isConnected
            ? connectedColor
            : (isConnecting ? connectingColor : disconnectedColor);
        final statusLabel = isConnected
            ? (localizations?.connected ?? 'CONNECTED')
            : (isConnecting
                ? (localizations?.connecting ?? 'CONNECTING...')
                : (localizations?.disconnected ?? 'DISCONNECTED'));

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: rotationTooltip,
                        icon: Icon(
                          _isLandscapeLocked
                              ? Icons.screen_lock_rotation
                              : Icons.screen_rotation,
                          color: textColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _isLandscapeLocked = !_isLandscapeLocked;
                            if (_isLandscapeLocked) {
                              SystemChrome.setPreferredOrientations(
                                _landscapeOrientations,
                              );
                            } else {
                              SystemChrome.setPreferredOrientations(
                                _allOrientations,
                              );
                            }
                          });
                        },
                      ),
                      if (_driveWheels == 4 && _mecanumWheels)
                        IconButton(
                          tooltip: _showMovementMatrix
                              ? (localizations?.hideMovementMatrix ??
                                  'Hide movement matrix')
                              : (localizations?.showMovementMatrix ??
                                  'Show movement matrix'),
                          icon: Icon(
                            _showMovementMatrix
                                ? Icons.apps
                                : Icons.apps_outlined,
                            color: textColor,
                          ),
                          onPressed: _toggleMovementMatrix,
                        ),
                      IconButton(
                        icon: Icon(Icons.terminal, color: textColor),
                        tooltip: 'Terminal',
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TerminalPage(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: textColor),
                        tooltip: localizations?.settings ?? 'Settings',
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsPage(
                                themeProvider: widget.themeProvider,
                                localeProvider: widget.localeProvider,
                              ),
                            ),
                          );
                          await _loadDriveSettings();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoystick({
    required String label,
    required Offset value,
    required ValueChanged<Offset> onChanged,
    required bool horizontalOnly,
    required double joystickSize,
    required double thumbSize,
    required double translateFactor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final joystickBgColor = isDark
        ? Colors.grey.shade800
        : Colors.grey.shade400;
    final joystickThumbColor = isDark ? Colors.blue : Colors.blue[700]!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          header: true,
          label: label,
          child: ExcludeSemantics(
            child: Text(label, style: TextStyle(color: textColor)),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: label,
          value: '${(value.dx * 100).toStringAsFixed(0)}%, ${(value.dy * 100).toStringAsFixed(0)}%',
          child: GestureDetector(
            onPanStart: (details) => _handleJoystickPan(
              localPosition: details.localPosition,
              joystickSize: joystickSize,
              translateFactor: translateFactor,
              horizontalOnly: horizontalOnly,
              onChanged: onChanged,
            ),
            onPanUpdate: (details) => _handleJoystickPan(
              localPosition: details.localPosition,
              joystickSize: joystickSize,
              translateFactor: translateFactor,
              horizontalOnly: horizontalOnly,
              onChanged: onChanged,
            ),
            onPanEnd: (_) => onChanged(Offset.zero),
            onPanCancel: () => onChanged(Offset.zero),
            child: Container(
              width: joystickSize,
              height: joystickSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: joystickBgColor,
              ),
              child: Center(
                child: Transform.translate(
                  offset: Offset(
                    value.dx * translateFactor,
                    value.dy * translateFactor,
                  ),
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: joystickThumbColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleJoystickPan({
    required Offset localPosition,
    required double joystickSize,
    required double translateFactor,
    required bool horizontalOnly,
    required ValueChanged<Offset> onChanged,
  }) {
    final center = Offset(joystickSize / 2, joystickSize / 2);
    final offset = localPosition - center;
    var normalized = _normalizeFromCenter(offset, translateFactor);

    if (horizontalOnly) {
      normalized = Offset(normalized.dx, 0.0);
    }

    onChanged(normalized);
  }

  Offset _normalizeFromCenter(Offset offset, double maxDistance) {
    final distance = offset.distance;
    if (distance == 0) return Offset.zero;

    final limitedDistance = distance > maxDistance ? maxDistance : distance;
    final normalized = offset / distance * limitedDistance;

    final raw = Offset(
      (normalized.dx / maxDistance).clamp(-1.0, 1.0),
      (normalized.dy / maxDistance).clamp(-1.0, 1.0),
    );

    return _applyRadialCurve(raw);
  }

  Offset _applyRadialCurve(Offset raw) {
    final magnitude = raw.distance;
    if (magnitude == 0) return Offset.zero;

    final scaled = magnitude.clamp(0.0, 1.0);
    final curved = math.pow(scaled, _responseGamma).toDouble();
    final dir = raw / magnitude;
    return Offset(dir.dx * curved, dir.dy * curved);
  }

  void _sendCurrentControl() {
    final translated = _applyTranslationAssist(_leftJoystick);
    final forwardAxis = -translated.dy;
    // If vehicle is 2-wheel or the user selected 4-wheel but not mecanum,
    // do not send strafe (tx). Only send tx when mecanum is enabled.
    final tx = (_driveWheels == 4 && _mecanumWheels) ? translated.dx : 0.0;
    _controlManager.sendJoystick(
      tx,
      forwardAxis,
      _rightJoystick.dx,
    );
  }

  Offset _applyTranslationAssist(Offset input) {
    if (input.distance < _translationDeadzone) {
      return Offset.zero;
    }

    var adjusted = input;
    if (adjusted.dx.abs() < _translationAxisSnap) {
      adjusted = Offset(0.0, adjusted.dy);
    }
    if (adjusted.dy.abs() < _translationAxisSnap) {
      adjusted = Offset(adjusted.dx, 0.0);
    }
    // If vehicle is 2-wheel differential, approximate diagonal to nearest
    // cardinal axis (prefer the larger axis).
    if (_driveWheels == 2) {
      if (adjusted.dx != 0.0 && adjusted.dy != 0.0) {
        if (adjusted.dx.abs() > adjusted.dy.abs()) {
          adjusted = Offset(adjusted.dx, 0.0);
        } else {
          adjusted = Offset(0.0, adjusted.dy);
        }
      }
    }

    return adjusted;
  }

  void _setMotionCommand(MotionCommand direction) {
    if (_activeMotion == direction) return;
    setState(() {
      _activeMotion = direction;
      _leftJoystick = Offset.zero;
      _rightJoystick = Offset.zero;
    });
    _controlManager.setMotionCommand(direction, power: _motionCommandPower);
    _sendCurrentControl();
  }

  void _clearMotionCommand() {
    if (_activeMotion == null) return;
    setState(() => _activeMotion = null);
    _controlManager.setMotionCommand(null);
    _sendCurrentControl();
  }

  Future<void> _loadDriveSettings() async {
    final wheels = await _settingsManager.loadDriveWheelsMode();
    final mech = await _settingsManager.loadMecanumPreference();
    if (!mounted) return;
    setState(() {
      _driveWheels = wheels;
      _mecanumWheels = mech;
      if (_driveWheels == 2) {
        _showMovementMatrix = false;
      }
    });
  }

  Widget _buildMotionPad({required bool isLandscape}) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final spacing = isLandscape ? 8.0 : 10.0;
    final buttonSize = isLandscape ? 52.0 : 56.0;

    return Column(
      children: [
        Text(
          localizations?.movementMatrix ?? 'MOVEMENT MATRIX',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.85),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDirectionButton(
              direction: MotionCommand.forward,
              icon: Icons.keyboard_arrow_up,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.backward,
              icon: Icons.keyboard_arrow_down,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.left,
              icon: Icons.keyboard_arrow_left,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.right,
              icon: Icons.keyboard_arrow_right,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.rotateRight,
              icon: Icons.rotate_right,
              size: buttonSize,
            ),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDirectionButton(
              direction: MotionCommand.forwardLeft,
              icon: Icons.north_west,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.backwardLeft,
              icon: Icons.south_west,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.forwardRight,
              icon: Icons.north_east,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.backwardRight,
              icon: Icons.south_east,
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.rotateLeft,
              icon: Icons.rotate_left,
              size: buttonSize,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectionButton({
    required MotionCommand direction,
    required IconData icon,
    required double size,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _activeMotion == direction;
    final baseColor = isDark ? Colors.blueGrey.shade800 : Colors.grey.shade400;
    final activeColor = isDark ? Colors.blue.shade500 : Colors.blue.shade700;
    const fgColor = Colors.white;
    final label = _motionCommandLabel(direction);

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _setMotionCommand(direction),
          onPointerUp: (_) => _clearMotionCommand(),
          onPointerCancel: (_) => _clearMotionCommand(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive ? activeColor : baseColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isActive ? 0.35 : 0.20),
                  blurRadius: isActive ? 16 : 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: ExcludeSemantics(
                child: Icon(icon, color: fgColor, size: size * 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _motionCommandLabel(MotionCommand direction) {
    final loc = AppLocalizations.of(context);
    switch (direction) {
      case MotionCommand.forward:
        return loc?.moveForward ?? 'Move forward';
      case MotionCommand.backward:
        return loc?.moveBackward ?? 'Move backward';
      case MotionCommand.left:
        return loc?.moveLeft ?? 'Move left';
      case MotionCommand.right:
        return loc?.moveRight ?? 'Move right';
      case MotionCommand.rotateRight:
        return loc?.rotateRightCmd ?? 'Rotate right';
      case MotionCommand.rotateLeft:
        return loc?.rotateLeftCmd ?? 'Rotate left';
      case MotionCommand.forwardLeft:
        return loc?.moveForwardLeft ?? 'Move forward left';
      case MotionCommand.backwardLeft:
        return loc?.moveBackwardLeft ?? 'Move backward left';
      case MotionCommand.forwardRight:
        return loc?.moveForwardRight ?? 'Move forward right';
      case MotionCommand.backwardRight:
        return loc?.moveBackwardRight ?? 'Move backward right';
    }
  }
}
