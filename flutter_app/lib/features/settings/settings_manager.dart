import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';

/// SettingsManager: responsable de persistir preferencias y exponer
/// helpers reutilizables por la UI. Actualmente es un stub con las
/// claves y métodos de persistencia; puede crecer para contener la
/// lógica de negocio (conexiones, validaciones, etc.) en siguientes pasos.
class SettingsManager extends ChangeNotifier {
  static const String mainModeKey = 'main_mode';
  static const String bluetoothReminderKey = 'bluetooth_reminder_skip';
  static const String showTelemetryKey = 'show_telemetry';

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

  Future<bool> loadTelemetryPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(showTelemetryKey) ?? true;
  }

  Future<void> persistTelemetryPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showTelemetryKey, value);
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
