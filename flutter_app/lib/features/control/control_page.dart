import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';
import 'package:flutter_rccontroller_app/transport/ble_transport.dart';
import 'package:flutter_rccontroller_app/transport/udp_transport.dart';

import '../../locale_provider.dart';
import '../../theme_provider.dart';
import '../settings/settings.dart';

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
  bool _wasConnected = false;

  final ControlManager _controlManager = ControlManager.instance;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(_allOrientations);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _wasConnected = _controlManager.isConnected;
    _controlManager.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    if (!mounted) return;

    final isConnected = _controlManager.isConnected;
    final currentRoute = ModalRoute.of(context);
    final localizations = AppLocalizations.of(context);

    if (_wasConnected && !isConnected && currentRoute?.isCurrent == true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              localizations?.connectionLost ?? 'Connection lost',
            ),
            duration: Duration(seconds: 2),
          ),
        );
    }

    _wasConnected = isConnected;
  }

  void _toggleMovementMatrix() {
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
    _controlManager.setMotionCommand(null);
    _controlManager.sendJoystick(0, 0, 0, 0);
    _controlManager.removeListener(_onConnectionChanged);
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
                                    setState(() => _leftJoystick = v);
                                    _sendCurrentControl();
                                  },
                                  joystickSize: joystickSize,
                                  thumbSize: thumbSize,
                                  translateFactor: translateFactor,
                                ),
                              ),
                              if (_showMovementMatrix) ...[
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
                                          setState(() => _leftJoystick = v);
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
                              if (_showMovementMatrix) ...[
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

    return ListenableBuilder(
      listenable: _controlManager,
      builder: (context, _) {
        final isConnected = _controlManager.isConnected;
        final transport = _controlManager.transport;
        final gps = _controlManager.gpsTelemetry;

        final connectedIcon = switch (transport) {
          UdpTransport() => Icons.wifi,
          BluetoothTransport() => Icons.bluetooth,
          _ => Icons.link,
        };
        final disconnectedIcon = switch (transport) {
          UdpTransport() => Icons.wifi_off,
          BluetoothTransport() => Icons.bluetooth_disabled,
          _ => Icons.link_off,
        };

        final gpsColor = gps == null
            ? textColor.withValues(alpha: 0.8)
            : (gps.valid ? connectedColor : disconnectedColor);

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isConnected ? connectedIcon : disconnectedIcon,
                        color: isConnected ? connectedColor : disconnectedColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isConnected
                            ? (localizations?.connected ?? 'CONNECTED')
                            : (localizations?.disconnected ?? 'DISCONNECTED'),
                        style: TextStyle(
                          color: isConnected
                              ? connectedColor
                              : disconnectedColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
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
                        icon: Icon(Icons.settings, color: textColor),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsPage(
                                themeProvider: widget.themeProvider,
                                localeProvider: widget.localeProvider,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _gpsLabel(gps),
                style: TextStyle(color: gpsColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  String _gpsLabel(GpsTelemetry? gps) {
    final localizations = AppLocalizations.of(context);

    if (gps == null) {
      return localizations?.gpsWaiting ?? 'GPS: waiting for telemetry...';
    }

    final state = gps.valid
        ? (localizations?.gpsFix ?? 'FIX')
        : (localizations?.gpsNoFix ?? 'NO FIX');
    final lat = gps.latitude.toStringAsFixed(6);
    final lon = gps.longitude.toStringAsFixed(6);
    final speed = gps.speedKmph.toStringAsFixed(1);
    final latLabel = localizations?.gpsLatLabel ?? 'lat';
    final lonLabel = localizations?.gpsLonLabel ?? 'lon';
    final satLabel = localizations?.gpsSatLabel ?? 'sat';
    final speedLabel = localizations?.gpsSpeedLabel ?? 'speed';

    return 'GPS $state | $latLabel: $lat | $lonLabel: $lon | $satLabel: ${gps.satellites} | $speedLabel: $speed km/h';
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
        Text(label, style: TextStyle(color: textColor)),
        const SizedBox(height: 12),
        GestureDetector(
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
    var normalized = _normalizeFromCenter(
      offset,
      translateFactor,
      deadZone: _controlManager.deadZone,
    );

    if (horizontalOnly) {
      normalized = Offset(normalized.dx, 0.0);
    }

    onChanged(normalized);
  }

  Offset _normalizeFromCenter(
    Offset offset,
    double maxDistance, {
    required double deadZone,
  }) {
    final distance = offset.distance;
    if (distance == 0) return Offset.zero;

    final limitedDistance = distance > maxDistance ? maxDistance : distance;
    final normalized = offset / distance * limitedDistance;

    final raw = Offset(
      (normalized.dx / maxDistance).clamp(-1.0, 1.0),
      (normalized.dy / maxDistance).clamp(-1.0, 1.0),
    );

    return _applyRadialDeadZoneAndCurve(raw, deadZone);
  }

  Offset _applyRadialDeadZoneAndCurve(Offset raw, double deadZone) {
    final dz = deadZone.clamp(0.0, 0.999);
    final magnitude = raw.distance;
    if (magnitude <= dz || magnitude == 0) return Offset.zero;

    final scaled = ((magnitude - dz) / (1.0 - dz)).clamp(0.0, 1.0);
    final curved = math.pow(scaled, _responseGamma).toDouble();
    final dir = raw / magnitude;
    return Offset(dir.dx * curved, dir.dy * curved);
  }

  void _sendCurrentControl() {
    final forwardAxis = -_leftJoystick.dy;
    _controlManager.sendJoystick(
      _leftJoystick.dx,
      forwardAxis,
      _rightJoystick.dx,
      0,
    );
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
              label: 'F',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.backward,
              icon: Icons.keyboard_arrow_down,
              label: 'B',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.left,
              icon: Icons.keyboard_arrow_left,
              label: 'L',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.right,
              icon: Icons.keyboard_arrow_right,
              label: 'R',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.rotateRight,
              icon: Icons.rotate_right,
              label: 'CW',
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
              label: 'G',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.backwardLeft,
              icon: Icons.south_west,
              label: 'H',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.forwardRight,
              icon: Icons.north_east,
              label: 'I',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.backwardRight,
              icon: Icons.south_east,
              label: 'J',
              size: buttonSize,
            ),
            SizedBox(width: spacing),
            _buildDirectionButton(
              direction: MotionCommand.rotateLeft,
              icon: Icons.rotate_left,
              label: 'CCW',
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
    required String label,
    required double size,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _activeMotion == direction;
    final baseColor = isDark ? Colors.blueGrey.shade800 : Colors.grey.shade400;
    final activeColor = isDark ? Colors.blue.shade500 : Colors.blue.shade700;
    const fgColor = Colors.white;

    return GestureDetector(
      onTapDown: (_) => _setMotionCommand(direction),
      onTapUp: (_) => _clearMotionCommand(),
      onTapCancel: _clearMotionCommand,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: size * 0.45),
            Text(
              label,
              style: const TextStyle(
                color: fgColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
