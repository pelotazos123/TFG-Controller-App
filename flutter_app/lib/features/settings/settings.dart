import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/transport/ble_transport.dart';
import 'package:flutter_rccontroller_app/transport/udp_transport.dart';
import '../../theme_provider.dart';

class SettingsPage extends StatefulWidget {
  final ThemeProvider? themeProvider;
  
  const SettingsPage({super.key, this.themeProvider});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _ipController = TextEditingController(text: '');
  final TextEditingController _portController = TextEditingController(text: '');

  final ControlManager _controlManager = ControlManager.instance;

  String _connectionType = 'WiFi';
  double _deadZone = 0.05;
  bool _reverseThrottle = false;
  bool _reverseSteering = false;

  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    // Forzar orientación vertical
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _deadZone = _controlManager.deadZone;
    _reverseSteering = _controlManager.reverseSteering;
    _reverseThrottle = _controlManager.reverseThrottle;

    _controlManager.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    setState(() {});
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
    _controlManager.removeListener(_onConnectionChanged);
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConnectionSection(),
          const Divider(height: 32),
          _buildControlSection(),
          const Divider(height: 32),
          _buildThemeSection(),
          const Divider(height: 32),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connection',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        
        ListTile(
          title: const Text('Connection Type'),
          trailing: DropdownButton<String>(
            value: _connectionType,
            items: const [
              DropdownMenuItem(value: 'WiFi', child: Text('WiFi')),
              DropdownMenuItem(value: 'Bluetooth', child: Text('Bluetooth')),
            ],
            onChanged: (value) {
              setState(() => _connectionType = value ?? 'WiFi');
            },
          ),
        ),
        
        if (_connectionType == 'WiFi') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'ESP32 IP Address',
                border: OutlineInputBorder(),
                hintText: '192.168.4.1',
              ),
              keyboardType: TextInputType.number,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
                hintText: '4210',
              ),
              keyboardType: TextInputType.number,
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_controlManager.isConnected || _isConnecting)
                        ? null
                        : () async {
                            setState(() => _isConnecting = true);
                            if (_connectionType == 'WiFi') {
                              final ip = _ipController.text.trim();
                              final port =
                                  int.tryParse(_portController.text.trim()) ?? 4210;

                              if (ip.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please enter ESP32 IP')),
                                );
                                if (mounted) {
                                  setState(() => _isConnecting = false);
                                }
                                return;
                              }

                              try {
                                _controlManager.setTransport(
                                  UdpTransport(ip: ip, port: port),
                                );
                                await _controlManager.connect();

                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('UDP Connected')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e is TimeoutException
                                          ? 'UDP connect timeout (no response from ESP32)'
                                          : 'Failed to connect UDP: $e',
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isConnecting = false);
                                }
                              }
                            } else {
                              try {
                                _controlManager.setTransport(BluetoothTransport());
                                await _controlManager.connect();

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Bluetooth Connected')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Failed to connect Bluetooth: $e')),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isConnecting = false);
                                }
                              }
                            }
                          },
                    child: _isConnecting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('Connecting...'),
                            ],
                          )
                        : Text(
                            _controlManager.isConnected
                                ? 'Connected'
                                : 'Connect',
                          ),
                  ),
                ),
                if (_controlManager.isConnected) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () {
                        _controlManager.disconnect();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Disconnected')),
                        );
                      },
                      child: const Text('Disconnect'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Control Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        
        // Dead Zone
        ListTile(
          title: const Text('Joystick Dead Zone'),
          subtitle: Text('${(_deadZone * 100).toStringAsFixed(0)}%'),
        ),
        Slider(
          value: _deadZone,
          min: 0.0,
          max: 0.3,
          divisions: 30,
          label: '${(_deadZone * 100).toStringAsFixed(0)}%',
          onChanged: (value) {
            setState(() => _deadZone = value);
            _controlManager.setDeadZone(value);
          },
        ),
        
        // Reverse Controls
        SwitchListTile(
          title: const Text('Reverse Steering'),
          value: _reverseSteering,
          onChanged: (value) {
            setState(() => _reverseSteering = value);
            _controlManager.setReverseSteering(value);
          },
        ),
        SwitchListTile(
          title: const Text('Reverse Throttle'),
          value: _reverseThrottle,
          onChanged: (value) {
            setState(() => _reverseThrottle = value);
            _controlManager.setReverseThrottle(value);
          },
        ),
      ],
    );
  }

  Widget _buildThemeSection() {
    if (widget.themeProvider == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        
        ListTile(
          title: const Text('Theme'),
          trailing: DropdownButton<ThemeMode>(
            value: widget.themeProvider!.themeMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('Light'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark'),
              ),
            ],
            onChanged: (ThemeMode? mode) {
              if (mode != null) {
                setState(() {
                  widget.themeProvider!.setThemeMode(mode);
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('App Name'),
          subtitle: const Text('RC Controller'),
        ),
        
        ListTile(
          leading: const Icon(Icons.tag),
          title: const Text('Version'),
          subtitle: const Text('1.0.0'),
        ),
        
        ListTile(
          leading: const Icon(Icons.memory),
          title: const Text('Hardware'),
          subtitle: const Text('ESP32-S3'),
        ),
        
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Developer'),
          subtitle: const Text('Pablo Calvo Gamonal'),
        ),
        
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Organization'),
          subtitle: const Text('Universidad de Oviedo'),
        ),

        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Description'),
          subtitle: const Text('Remote control application for ESP32-S3 based RC vehicles'),
        ),
      ],
    );
  }

}