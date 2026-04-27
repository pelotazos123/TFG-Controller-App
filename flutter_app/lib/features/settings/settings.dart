import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';
import 'package:flutter_rccontroller_app/transport/udp_transport.dart';
import '../../locale_provider.dart';
import '../../theme_provider.dart';

class SettingsPage extends StatefulWidget {
  final ThemeProvider? themeProvider;
  final LocaleProvider? localeProvider;

  const SettingsPage({super.key, this.themeProvider, this.localeProvider});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _portController = TextEditingController(
    text: '4210',
  );

  final ControlManager _controlManager = ControlManager.instance;

  String _connectionType = 'WiFi';
  double _deadZone = 0.05;
  double _driveScale = 1.0;
  bool _reverseThrottle = false;
  bool _reverseSteering = false;

  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _deadZone = _controlManager.deadZone;
    _driveScale = _controlManager.driveScale;
    _reverseSteering = _controlManager.reverseSteering;
    _reverseThrottle = _controlManager.reverseThrottle;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localizations?.settings ?? 'Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLanguageSection(localizations),
          const Divider(height: 32),
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

  Widget _buildLanguageSection(AppLocalizations? localizations) {
    Locale currentLocale = widget.localeProvider?.locale ?? Localizations.localeOf(context);
    String languageCode = currentLocale.languageCode;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.language ?? 'Language',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text(localizations?.language ?? 'Select Language'),
          trailing: DropdownButton<String>(
            value: ['en', 'es'].contains(languageCode) ? languageCode : 'en',
            items: [
              DropdownMenuItem(value: 'en', child: Text(localizations?.english ?? 'English')),
              DropdownMenuItem(value: 'es', child: Text(localizations?.spanish ?? 'Spanish')),
            ],
            onChanged: (value) {
              if (value != null) {
                widget.localeProvider?.setLocale(Locale(value));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionSection() {
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.connection ?? 'Connection',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text(localizations?.connectionType ?? 'Connection Type'),
          trailing: DropdownButton<String>(
            value: _connectionType,
            items: [
              DropdownMenuItem(
                value: 'WiFi',
                child: Text(localizations?.wifi ?? 'WiFi'),
              ),
              DropdownMenuItem(
                value: 'Bluetooth',
                child: Text(localizations?.bluetooth ?? 'Bluetooth'),
              ),
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
              decoration: InputDecoration(
                labelText: localizations?.esp32IpAddress ?? 'ESP32 IP Address',
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
              decoration: InputDecoration(
                labelText: localizations?.port ?? 'Port',
                border: OutlineInputBorder(),
                hintText: '4210',
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListenableBuilder(
              listenable: _controlManager,
              builder: (context, _) {
                final isConnected = _controlManager.isConnected;

                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isConnected || _isConnecting)
                            ? null
                            : () async {
                                setState(() => _isConnecting = true);
                                final messenger = ScaffoldMessenger.of(context);

                                final ip = _ipController.text.trim();
                                final port =
                                    int.tryParse(_portController.text.trim()) ??
                                    4210;

                                if (ip.isEmpty) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        localizations?.pleaseEnterEsp32Ip ??
                                            'Please enter ESP32 IP',
                                      ),
                                    ),
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
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        localizations?.udpConnected ??
                                            'UDP Connected',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e is TimeoutException
                                            ? (localizations
                                                    ?.udpConnectTimeout ??
                                                'UDP connect timeout (no response from ESP32)')
                                            : '${localizations?.failedToConnectUdp ?? 'Failed to connect UDP'}: $e',
                                      ),
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _isConnecting = false);
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    localizations?.connecting ??
                                        'Connecting...',
                                  ),
                                ],
                              )
                            : Text(
                                isConnected
                                    ? (localizations?.connected ?? 'Connected')
                                    : (localizations?.connect ?? 'Connect'),
                              ),
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          onPressed: () {
                            _controlManager.disconnect();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  localizations?.disconnected ??
                                      'Disconnected',
                                ),
                              ),
                            );
                          },
                          child: Text(
                            localizations?.disconnect ?? 'Disconnect',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlSection() {
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.controlSettings ?? 'Control Settings',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text(localizations?.joystickDeadZone ?? 'Joystick Dead Zone'),
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
        ListTile(
          title: Text(localizations?.maxDriveSpeed ?? 'Max Drive Speed'),
          subtitle: Text('${(_driveScale * 100).toStringAsFixed(0)}%'),
        ),
        Slider(
          value: _driveScale,
          min: 0.2,
          max: 1.0,
          divisions: 16,
          label: '${(_driveScale * 100).toStringAsFixed(0)}%',
          onChanged: (value) {
            setState(() => _driveScale = value);
            _controlManager.setDriveScale(value);
          },
        ),
        SwitchListTile(
          title: Text(localizations?.reverseStrafeX ?? 'Reverse Strafe (X)'),
          subtitle: Text(
            localizations?.leftJoystickHorizontalAxis ??
                'Left joystick horizontal axis',
          ),
          value: _reverseSteering,
          onChanged: (value) {
            setState(() => _reverseSteering = value);
            _controlManager.setReverseSteering(value);
          },
        ),
        SwitchListTile(
          title: Text(
            localizations?.reverseForwardBackY ?? 'Reverse Forward/Back (Y)',
          ),
          subtitle: Text(
            localizations?.leftJoystickVerticalAxis ??
                'Left joystick vertical axis',
          ),
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

    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.appearance ?? 'Appearance',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text(localizations?.theme ?? 'Theme'),
          trailing: DropdownButton<ThemeMode>(
            value: widget.themeProvider!.themeMode,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text(localizations?.system ?? 'System'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text(localizations?.light ?? 'Light'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text(localizations?.dark ?? 'Dark'),
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
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.about ?? 'About',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text(localizations?.appName ?? 'App Name'),
          subtitle: Text(localizations?.appTitle ?? 'RC Controller'),
        ),
        ListTile(
          leading: Icon(Icons.tag),
          title: Text(localizations?.version ?? 'Version'),
          subtitle: const Text('1.0.0'),
        ),
        ListTile(
          leading: Icon(Icons.memory),
          title: Text(localizations?.hardware ?? 'Hardware'),
          subtitle: Text('ESP32-S3'),
        ),
        ListTile(
          leading: Icon(Icons.person),
          title: Text(localizations?.developer ?? 'Developer'),
          subtitle: Text('Pablo Calvo Gamonal'),
        ),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text(localizations?.organization ?? 'Organization'),
          subtitle: Text('Universidad de Oviedo'),
        ),
        ListTile(
          leading: Icon(Icons.description),
          title: Text(localizations?.description ?? 'Description'),
          subtitle: Text(
            localizations?.appDescription ??
                'Remote control application for ESP32-S3 based RC vehicles',
          ),
        ),
      ],
    );
  }
}
