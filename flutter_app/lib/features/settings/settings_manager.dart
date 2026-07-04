import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';

class SettingsManager extends ChangeNotifier {
  static const String mainModeKey = 'main_mode';
  static const String bluetoothReminderKey = 'bluetooth_reminder_skip';
  static const String driveWheelsKey = 'drive_wheels'; // '2' or '4'
  static const String mecanumKey = 'mecanum_wheels';

  Future<ControllerMode> loadMainMode(ControllerMode fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(mainModeKey);
    if (raw == null) return fallback;
    return _modeFromPrefs(raw);
  }

  Future<void> persistMainMode(ControllerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(mainModeKey, _modeToPrefs(mode));
  }

  Future<bool> loadBluetoothReminderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(bluetoothReminderKey) ?? false;
  }

  Future<void> persistBluetoothReminderPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(bluetoothReminderKey, value);
  }

  Future<int> loadDriveWheelsMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(driveWheelsKey);
    if (raw == null) return 4;
    final val = int.tryParse(raw);
    if (val == 2) return 2;
    return 4;
  }

  Future<void> persistDriveWheelsMode(int wheels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(driveWheelsKey, wheels.toString());
  }

  Future<bool> loadMecanumPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(mecanumKey) ?? true;
  }

  Future<void> persistMecanumPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(mecanumKey, value);
  }

  String _modeToPrefs(ControllerMode mode) => controllerModeToPayload(mode);

  ControllerMode _modeFromPrefs(String raw) {
    switch (raw) {
      case 'wifi_ap':
        return ControllerMode.wifiAp;
      case 'ble':
        return ControllerMode.ble;
      default:
        return ControllerMode.ble;
    }
  }

  /// Validates an IPv4 address. Returns a localized error message or null.
  String? validateIp(String ip, AppLocalizations? localizations) {
    if (ip.isEmpty) {
      return localizations?.pleaseEnterEsp32Ip ?? 'Please enter ESP32 IP';
    }

    final address = InternetAddress.tryParse(ip);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return localizations?.invalidIpAddress ?? 'Enter a valid IPv4 address';
    }

    return null;
  }

  /// Validates a port string. Returns a localized error message or null.
  String? validatePort(String portText, AppLocalizations? localizations) {
    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      return localizations?.invalidPort ?? 'Enter a valid port (1-65535)';
    }
    return null;
  }
}
