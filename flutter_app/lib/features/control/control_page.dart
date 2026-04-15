import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/transport/ble_transport.dart';
import 'package:flutter_rccontroller_app/transport/udp_transport.dart';
import '../settings/settings.dart';
import '../../theme_provider.dart';

class ControlPage extends StatefulWidget {
  final ThemeProvider? themeProvider;
  
  const ControlPage({super.key, this.themeProvider});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
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

  Offset _leftJoystick = Offset.zero;  // steering
  Offset _rightJoystick = Offset.zero; // throttle

  bool _isLandscapeLocked = false;
  bool _wasConnected = false;

  final ControlManager _controlManager = ControlManager.instance;


  @override
  void initState() {
    super.initState();
    // Permitir todas las orientaciones inicialmente
    SystemChrome.setPreferredOrientations(_allOrientations);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    _wasConnected = _controlManager.isConnected;
    _controlManager.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    if (!mounted) return;

    final isConnected = _controlManager.isConnected;
    final currentRoute = ModalRoute.of(context);

    if (_wasConnected && !isConnected && currentRoute?.isCurrent == true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Connection lost'),
            duration: Duration(seconds: 2),
          ),
        );
    }

    _wasConnected = isConnected;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(_allOrientations);
    _controlManager.removeListener(_onConnectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.grey[200]!;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            final joystickSize = isLandscape ? 200.0 : 150.0;
            final thumbSize = isLandscape ? 60.0 : 45.0;
            final translateFactor = isLandscape ? 60.0 : 45.0;

            return Column(
              children: [
                _buildStatusBar(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildJoystick(
                          label: 'THROTTLE',
                          value: _leftJoystick,
                          onChanged: (v) {
                            setState(() => _leftJoystick = v);

                            _controlManager.sendJoystick(
                              _leftJoystick.dx,
                              _leftJoystick.dy,
                              _rightJoystick.dx,
                              _rightJoystick.dy,
                            );
                          },
                          joystickSize: joystickSize,
                          thumbSize: thumbSize,
                          translateFactor: translateFactor,
                        ),
                      ),
                      Expanded(
                        child: _buildJoystick(
                          label: 'STEERING',
                          value: _rightJoystick,
                          onChanged: (v) {
                            setState(() => _rightJoystick = v);

                            _controlManager.sendJoystick(
                              _leftJoystick.dx,
                              _leftJoystick.dy,
                              _rightJoystick.dx,
                              _rightJoystick.dy,
                            );
                          },
                          joystickSize: joystickSize,
                          thumbSize: thumbSize,
                          translateFactor: translateFactor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  Widget _buildStatusBar() {
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
                        isConnected ? 'CONNECTED' : 'DISCONNECTED',
                        style: TextStyle(
                          color: isConnected ? connectedColor : disconnectedColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isLandscapeLocked ? Icons.screen_lock_rotation : Icons.screen_rotation,
                          color: textColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _isLandscapeLocked = !_isLandscapeLocked;
                            if (_isLandscapeLocked) {
                              SystemChrome.setPreferredOrientations(_landscapeOrientations);
                            } else {
                              SystemChrome.setPreferredOrientations(_allOrientations);
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: textColor),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsPage(themeProvider: widget.themeProvider),
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
                style: TextStyle(
                  color: gpsColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _gpsLabel(GpsTelemetry? gps) {
    if (gps == null) {
      return 'GPS: waiting for telemetry...';
    }

    final state = gps.valid ? 'FIX' : 'NO FIX';
    final lat = gps.latitude.toStringAsFixed(6);
    final lon = gps.longitude.toStringAsFixed(6);
    final speed = gps.speedKmph.toStringAsFixed(1);

    return 'GPS $state | lat: $lat | lon: $lon | sat: ${gps.satellites} | speed: $speed km/h';
  }

  Widget _buildJoystick({
    required String label,
    required Offset value,
    required ValueChanged<Offset> onChanged,
    required double joystickSize,
    required double thumbSize,
    required double translateFactor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final joystickBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade400;
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
            onChanged: onChanged,
          ),
          onPanUpdate: (details) => _handleJoystickPan(
            localPosition: details.localPosition,
            joystickSize: joystickSize,
            translateFactor: translateFactor,
            onChanged: onChanged,
          ),
          onPanEnd: (_) {
            onChanged(Offset.zero);
          },
          child: Container(
            width: joystickSize,
            height: joystickSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: joystickBgColor,
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(value.dx * translateFactor, value.dy * translateFactor),
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


  // ---------------- LOGIC ----------------

  void _handleJoystickPan({
    required Offset localPosition,
    required double joystickSize,
    required double translateFactor,
    required ValueChanged<Offset> onChanged,
  }) {
    final center = Offset(joystickSize / 2, joystickSize / 2);
    final offset = localPosition - center;
    onChanged(_normalizeFromCenter(
      offset,
      translateFactor,
      deadZone: _controlManager.deadZone,
    ));
  }

  Offset _normalizeFromCenter(
    Offset offset,
    double maxDistance, {
    required double deadZone,
  }) {
    final distance = offset.distance;
    if (distance == 0) return Offset.zero;
    
    // Limitar al radio máximo
    final limitedDistance = distance > maxDistance ? maxDistance : distance;
    final normalized = offset / distance * limitedDistance;
    
    // Normalize range from -1.0 to 1.0
    final raw = Offset(
      (normalized.dx / maxDistance).clamp(-1.0, 1.0),
      (normalized.dy / maxDistance).clamp(-1.0, 1.0),
    );

    return Offset(
      _applyDeadZone(raw.dx, deadZone),
      _applyDeadZone(raw.dy, deadZone),
    );
  }

  double _applyDeadZone(double value, double deadZone) {
    final dz = deadZone.clamp(0.0, 0.999);
    final absValue = value.abs();
    if (absValue <= dz) return 0.0;

    // Rescale so output still reaches 1.0 at the edge
    final scaled = (absValue - dz) / (1.0 - dz);
    return value.isNegative ? -scaled : scaled;
  }

}
