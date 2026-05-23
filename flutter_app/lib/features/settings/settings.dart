import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';
import 'package:flutter_rccontroller_app/transport/ble_transport.dart';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
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
  static const String _mainModeKey = 'main_mode';
  static const String _bluetoothReminderKey = 'bluetooth_reminder_skip';
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _portController = TextEditingController(
    text: '4210',
  );

  final ControlManager _controlManager = ControlManager.instance;

  ControllerMode _mainMode = ControllerMode.wifiAp;
  ControllerMode _connectionMode = ControllerMode.wifiAp;
  ControllerMode? _activeMode;
  double _driveScale = 1.0;
  bool _reverseThrottle = false;
  bool _reverseSteering = false;
  bool _skipBluetoothReminder = false;

  bool _isConnecting = false;

  bool _matchesSelectedMode(ControlTransport? transport) {
    final resolved = _resolveActiveMode(transport);
    if (resolved != null) return _connectionMode == resolved;

    if (transport is UdpTransport) {
      return _connectionMode == ControllerMode.wifiAp;
    }
    if (transport is BleTransport) {
      return _connectionMode == ControllerMode.ble;
    }
    return false;
  }

  ControllerMode? _resolveActiveMode(ControlTransport? transport) {
    if (_activeMode != null) return _activeMode;
    if (transport is BleTransport) return ControllerMode.ble;
    if (transport is UdpTransport) return ControllerMode.wifiAp;
    return null;
  }

  String _shortModeLabel(ControllerMode mode) {
    switch (mode) {
      case ControllerMode.wifiAp:
        return 'AP';
      case ControllerMode.ble:
        return 'BLE';
    }
  }

  @override
  void initState() {
    super.initState();
    _driveScale = _controlManager.driveScale;
    _reverseSteering = _controlManager.reverseSteering;
    _reverseThrottle = _controlManager.reverseThrottle;

    _loadMainMode();
    _loadBluetoothReminderPreference();

    final active = _resolveActiveMode(_controlManager.transport);
    if (active != null) {
      _activeMode = active;
      _connectionMode = active;
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadMainMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mainModeKey);
    final resolved = raw == null ? _mainMode : _modeFromPrefs(raw);

    if (!mounted) return;
    setState(() {
      _mainMode = resolved;
      if (!_controlManager.isConnected) {
        _connectionMode = resolved;
      }
    });
  }

  Future<void> _loadBluetoothReminderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final skip = prefs.getBool(_bluetoothReminderKey) ?? false;
    if (!mounted) return;
    setState(() => _skipBluetoothReminder = skip);
  }

  Future<void> _persistBluetoothReminderPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bluetoothReminderKey, value);
    if (!mounted) return;
    setState(() => _skipBluetoothReminder = value);
  }

  Future<void> _persistMainMode(ControllerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mainModeKey, _modeToPrefs(mode));
  }

  Future<void> _setMainMode(ControllerMode mode) async {
    setState(() {
      _mainMode = mode;
    });
    await _persistMainMode(mode);

    final transport = _controlManager.transport;
    if (transport == null || !transport.isConnected) return;
    try {
      await transport.sendMainModeCommand(mode);
    } catch (_) {
      // Ignore failures when persisting main mode to the controller.
    }
  }

  String _modeToPrefs(ControllerMode mode) => controllerModeToPayload(mode);

  ControllerMode _modeFromPrefs(String raw) {
    switch (raw) {
      case 'wifi_ap':
        return ControllerMode.wifiAp;
      case 'ble':
        return ControllerMode.ble;
      default:
        return ControllerMode.wifiAp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final title = localizations?.settings ?? 'Settings';
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? Semantics(
                button: true,
                label: '$title, ${localizations?.back ?? 'Back'}',
                child: IconButton(
                  tooltip: '$title, back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              )
            : null,
        title: Text(title),
        centerTitle: true,
      ),
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
    final selectedLanguage = ['en', 'es'].contains(languageCode) ? languageCode : 'en';
    final selectedLanguageLabel = selectedLanguage == 'en'
        ? (localizations?.english ?? 'English')
        : (localizations?.spanish ?? 'Spanish');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(localizations?.language ?? 'Language'),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: '${localizations?.language ?? 'Select Language'}: $selectedLanguageLabel',
          child: ListTile(
            title: Text(localizations?.language ?? 'Select Language'),
            trailing: DropdownButton<String>(
              value: selectedLanguage,
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
        ),
      ],
    );
  }

  Widget _buildConnectionSection() {
    final localizations = AppLocalizations.of(context);
    final isMainSelected = _connectionMode == _mainMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(localizations?.connection ?? 'Connection'),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: localizations?.connectionType ?? 'Connection Type',
          child: ListTile(
            title: Text(localizations?.connectionType ?? 'Connection Type'),
            trailing: DropdownButton<ControllerMode>(
              value: _connectionMode,
              items: [
                DropdownMenuItem(
                  value: ControllerMode.wifiAp,
                  child: Text(localizations?.wifiAp ?? 'WiFi AP'),
                ),
                DropdownMenuItem(
                  value: ControllerMode.ble,
                  child: Text(localizations?.bluetoothLe ?? 'Bluetooth LE'),
                ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _connectionMode = value);
              },
            ),
          ),
        ),
        SwitchListTile(
          title: Text(localizations?.mainMode ?? 'Main mode'),
          subtitle: Text(
            localizations?.mainModeDescription ??
                'Use selected mode for next startup',
          ),
          value: isMainSelected,
          onChanged: (value) async {
            if (!value || isMainSelected) return;
            await _setMainMode(_connectionMode);
          },
        ),
        if (_connectionMode == ControllerMode.wifiAp) ...[
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
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListenableBuilder(
            listenable: _controlManager,
            builder: (context, _) {
              final isConnected = _controlManager.isConnected;
              final activeMode = _resolveActiveMode(_controlManager.transport);
              final matchesMode = _matchesSelectedMode(
                _controlManager.transport,
              );
              final showChangeMode =
                  isConnected && activeMode != null && activeMode != _connectionMode;
              final canConnect =
                  !_isConnecting && (!isConnected || !matchesMode);
              final disconnectLabel = activeMode != null
                  ? '${localizations?.disconnect ?? 'Disconnect'} ${_shortModeLabel(activeMode)}'
                  : (localizations?.disconnect ?? 'Disconnect');

              if (showChangeMode) {
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isConnecting
                            ? null
                            : () async {
                                setState(() => _isConnecting = true);
                                final messenger = ScaffoldMessenger.of(context);

                                try {
                                  await _changeMode(localizations);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        localizations?.disconnected ??
                                            'Disconnected',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString()),
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
                                  Flexible(
                                    child: Text(
                                      localizations?.connecting ??
                                          'Connecting...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Text(localizations?.changeMode ?? 'Change mode'),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canConnect
                          ? () async {
                              setState(() => _isConnecting = true);
                              final messenger = ScaffoldMessenger.of(context);

                              try {
                                if (_connectionMode == ControllerMode.ble) {
                                  await _showBluetoothReminder(localizations);
                                }
                                await _connectToSelectedMode(localizations);

                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      localizations?.connected ?? 'Connected',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e is TimeoutException
                                          ? (localizations?.udpConnectTimeout ??
                                              'UDP connect timeout (no response from ESP32)')
                                          : e.toString(),
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isConnecting = false);
                                }
                              }
                            }
                          : null,
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
                                Flexible(
                                  child: Text(
                                    localizations?.connecting ?? 'Connecting...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              isConnected && matchesMode
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
                        onPressed: () async {
                          _controlManager.disconnect();
                          if (mounted) {
                            setState(() => _activeMode = null);
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localizations?.disconnected ?? 'Disconnected',
                              ),
                            ),
                          );
                        },
                        child: Text(disconnectLabel),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showBluetoothReminder(
    AppLocalizations? localizations,
  ) async {
    if (_skipBluetoothReminder) return;

    final title = localizations?.bluetoothLe ?? 'Bluetooth LE';
    final body = localizations?.bluetoothReminderBody ??
        'Make sure Bluetooth is enabled on your phone.';
    final openSettingsLabel =
        localizations?.bluetoothOpenSettings ?? 'Open settings';
    final okLabel = localizations?.ok ?? 'OK';
    bool rememberChoice = _skipBluetoothReminder;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: rememberChoice,
                    title: Text(localizations?.rememberThis ?? 'Remember this'),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) {
                      setDialogState(() => rememberChoice = value == true);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (rememberChoice) {
                      await _persistBluetoothReminderPreference(true);
                    }
                  },
                  child: Text(okLabel),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (rememberChoice) {
                      await _persistBluetoothReminderPreference(true);
                    }
                    await _openBluetoothSettings();
                  },
                  child: Text(openSettingsLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openBluetoothSettings() async {
    if (!Platform.isAndroid) return;

    const intent = AndroidIntent(
      action: 'android.settings.BLUETOOTH_SETTINGS',
    );
    await intent.launch();
  }

  Future<void> _changeMode(AppLocalizations? localizations) async {
    final currentTransport = _controlManager.transport;
    if (currentTransport == null || !currentTransport.isConnected) {
      throw Exception(
        localizations?.connectFirstToSwitch ??
            'Connect to the controller first to switch modes.',
      );
    }

    final mode = _connectionMode;
    if (mode == ControllerMode.ble) {
      await _showBluetoothReminder(localizations);
    }

    _controlManager.pauseSending();

    for (var i = 0; i < 3; i += 1) {
      try {
        await currentTransport.sendModeCommand(mode);
      } catch (_) {
        // Ignore write errors during mode switch attempts.
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    _controlManager.disconnect();
    if (mounted) {
      setState(() => _activeMode = null);
    }
  }

  Future<void> _connectToSelectedMode(AppLocalizations? localizations) async {
    final mode = _connectionMode;

    if (mode == ControllerMode.wifiAp) {
      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 4210;

      if (ip.isEmpty) {
        throw Exception(
          localizations?.pleaseEnterEsp32Ip ?? 'Please enter ESP32 IP',
        );
      }

      final transport = UdpTransport(ip: ip, port: port);
      _controlManager.setTransport(transport);
      await _controlManager.connect();

      await transport.sendModeCommand(mode);
      if (mounted) {
        setState(() => _activeMode = mode);
      }
      return;
    }

    final currentTransport = _controlManager.transport;
    if (currentTransport != null && currentTransport.isConnected) {
      _controlManager.disconnect();
    }

    final transport = BleTransport();
    _controlManager.setTransport(transport);
    await _connectWithRetry(transport);
    await transport.sendModeCommand(mode);
    if (mounted) {
      setState(() => _activeMode = mode);
    }
  }

  Future<void> _connectWithRetry(ControlTransport transport) async {
    const attempts = 3;
    for (var i = 0; i < attempts; i += 1) {
      try {
        await _controlManager.connect();
        return;
      } catch (_) {
        if (i == attempts - 1) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Widget _buildControlSection() {
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(localizations?.controlSettings ?? 'Control Settings'),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: localizations?.maxDriveSpeed ?? 'Max Drive Speed',
          child: ListTile(
            title: Text(localizations?.maxDriveSpeed ?? 'Max Drive Speed'),
            subtitle: Text('${(_driveScale * 100).toStringAsFixed(0)}%'),
          ),
        ),
        Slider(
          value: _driveScale,
          min: 0.2,
          max: 1.0,
          divisions: 16,
          label: localizations?.maxDriveSpeed ?? 'Max Drive Speed',
          onChanged: (value) {
            setState(() => _driveScale = value);
            _controlManager.setDriveScale(value);
          },
              semanticFormatterCallback: (double value) =>
                '${(value * 100).toStringAsFixed(0)}%',
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
        _buildSectionHeader(localizations?.appearance ?? 'Appearance'),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: '${localizations?.theme ?? 'Theme'}: ${switch (widget.themeProvider!.themeMode) { ThemeMode.system => localizations?.system ?? 'System', ThemeMode.light => localizations?.light ?? 'Light', ThemeMode.dark => localizations?.dark ?? 'Dark' }}',
          child: ListTile(
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
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(localizations?.about ?? 'About'),
        const SizedBox(height: 16),
        _buildAboutTile(
          icon: Icons.info_outline,
          title: localizations?.appName ?? 'App Name',
          subtitle: localizations?.appTitle ?? 'RC Controller',
        ),
        _buildAboutTile(
          icon: Icons.tag,
          title: localizations?.version ?? 'Version',
          subtitle: '1.0.0',
        ),
        _buildAboutTile(
          icon: Icons.memory,
          title: localizations?.hardware ?? 'Hardware',
          subtitle: 'ESP32-S3',
        ),
        _buildAboutTile(
          icon: Icons.person,
          title: localizations?.developer ?? 'Developer',
          subtitle: 'Pablo Calvo Gamonal',
        ),
        _buildAboutTile(
          icon: Icons.info_outline,
          title: localizations?.organization ?? 'Organization',
          subtitle: 'Universidad de Oviedo',
        ),
        _buildAboutTile(
          icon: Icons.description,
          title: localizations?.description ?? 'Description',
          subtitle: localizations?.appDescription ??
              'Remote control application for ESP32-S3 based RC vehicles',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String text) {
    return Semantics(
      header: true,
      child: ExcludeSemantics(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAboutTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Semantics(
      container: true,
      label: '$title: $subtitle',
      child: ListTile(
        leading: ExcludeSemantics(child: Icon(icon)),
        title: ExcludeSemantics(child: Text(title)),
        subtitle: ExcludeSemantics(child: Text(subtitle)),
      ),
    );
  }
}
