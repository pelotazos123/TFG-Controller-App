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
  Offset _leftJoystick = Offset.zero;  // steering
  Offset _rightJoystick = Offset.zero; // throttle

  bool _isLandscapeLocked = false;

  final ControlManager _controlManager = ControlManager.instance;


  @override
  void initState() {
    super.initState();
    // Permitir todas las orientaciones inicialmente
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // Restaurar orientaciones permitidas
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
                          label: 'STEERING',
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
                          label: 'THROTTLE',
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
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ListenableBuilder(
            listenable: _controlManager,
            builder: (context, _) {
              final isConnected = _controlManager.isConnected;
              final transport = _controlManager.transport;

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

              return Row(
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
              );
            },
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
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                    } else {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
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
    );
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
          onPanStart: (details) {
            final center = Offset(joystickSize / 2, joystickSize / 2);
            final localPosition = details.localPosition;
            final offset = localPosition - center;
            onChanged(_normalizeFromCenter(offset, translateFactor));
          },
          onPanUpdate: (details) {
            final center = Offset(joystickSize / 2, joystickSize / 2);
            final localPosition = details.localPosition;
            final offset = localPosition - center;
            onChanged(_normalizeFromCenter(offset, translateFactor));
          },
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

  Offset _normalizeFromCenter(Offset offset, double maxDistance) {
    final distance = offset.distance;
    if (distance == 0) return Offset.zero;
    
    // Limitar al radio máximo
    final limitedDistance = distance > maxDistance ? maxDistance : distance;
    final normalized = offset / distance * limitedDistance;
    
    // Convertir a rango -1.0 a 1.0
    return Offset(
      (normalized.dx / maxDistance).clamp(-1.0, 1.0),
      (normalized.dy / maxDistance).clamp(-1.0, 1.0),
    );
  }

}
