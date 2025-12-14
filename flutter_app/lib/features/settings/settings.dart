import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme_provider.dart';

class SettingsPage extends StatefulWidget {
  final ThemeProvider? themeProvider;
  
  const SettingsPage({super.key, this.themeProvider});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.4.1');
  final TextEditingController _portController = TextEditingController(text: '80');
  
  String _connectionType = 'WiFi';
  double _deadZone = 0.05;
  int _updateRate = 50;
  bool _reverseThrottle = false;
  bool _reverseSteering = false;

  @override
  void initState() {
    super.initState();
    // Forzar orientación vertical
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
          _buildAdvancedSection(),
          const Divider(height: 32),
          _buildThemeSection(),
          const Divider(height: 32),
          _buildAboutSection(),
          const SizedBox(height: 24),
          _buildSaveButton(),
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
        
        // Connection Type
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
        
        // IP Address
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
          
          // Port
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
                hintText: '80',
              ),
              keyboardType: TextInputType.number,
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
          },
        ),
        
        // Reverse Controls
        SwitchListTile(
          title: const Text('Reverse Steering'),
          value: _reverseSteering,
          onChanged: (value) {
            setState(() => _reverseSteering = value);
          },
        ),
        SwitchListTile(
          title: const Text('Reverse Throttle'),
          value: _reverseThrottle,
          onChanged: (value) {
            setState(() => _reverseThrottle = value);
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        
        // Update Rate
        ListTile(
          title: const Text('Update Rate'),
          subtitle: Text('$_updateRate ms'),
        ),
        Slider(
          value: _updateRate.toDouble(),
          min: 20,
          max: 200,
          divisions: 18,
          label: '$_updateRate ms',
          onChanged: (value) {
            setState(() => _updateRate = value.toInt());
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

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
      ),
      icon: const Icon(Icons.save),
      label: const Text(
        'Save Settings',
        style: TextStyle(fontSize: 18),
      ),
      onPressed: () {
        // TODO: Save settings to shared preferences
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      },
    );
  }
}