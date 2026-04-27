// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RC Controller';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get connection => 'Connection';

  @override
  String get connectionType => 'Connection Type';

  @override
  String get wifi => 'WiFi';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get esp32IpAddress => 'ESP32 IP Address';

  @override
  String get port => 'Port';

  @override
  String get pleaseEnterEsp32Ip => 'Please enter ESP32 IP';

  @override
  String get udpConnected => 'UDP Connected';

  @override
  String get udpConnectTimeout =>
      'UDP connect timeout (no response from ESP32)';

  @override
  String get failedToConnectUdp => 'Failed to connect UDP';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connect => 'Connect';

  @override
  String get connected => 'Connected';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connectionLost => 'Connection lost';

  @override
  String get controlSettings => 'Control Settings';

  @override
  String get joystickDeadZone => 'Joystick Dead Zone';

  @override
  String get maxDriveSpeed => 'Max Drive Speed';

  @override
  String get reverseStrafeX => 'Reverse Strafe (X)';

  @override
  String get leftJoystickHorizontalAxis => 'Left joystick horizontal axis';

  @override
  String get reverseForwardBackY => 'Reverse Forward/Back (Y)';

  @override
  String get leftJoystickVerticalAxis => 'Left joystick vertical axis';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get about => 'About';

  @override
  String get appName => 'App Name';

  @override
  String get version => 'Version';

  @override
  String get hardware => 'Hardware';

  @override
  String get developer => 'Developer';

  @override
  String get organization => 'Organization';

  @override
  String get description => 'Description';

  @override
  String get appDescription =>
      'Remote control application for ESP32-S3 based RC vehicles';

  @override
  String get translation => 'TRANSLATION';

  @override
  String get rotation => 'ROTATION';

  @override
  String get movementMatrix => 'MOVEMENT MATRIX';

  @override
  String get hideMovementMatrix => 'Hide movement matrix';

  @override
  String get showMovementMatrix => 'Show movement matrix';

  @override
  String get gpsWaiting => 'GPS: waiting for telemetry...';

  @override
  String get gpsFix => 'FIX';

  @override
  String get gpsNoFix => 'NO FIX';

  @override
  String get gpsLatLabel => 'lat';

  @override
  String get gpsLonLabel => 'lon';

  @override
  String get gpsSatLabel => 'sat';

  @override
  String get gpsSpeedLabel => 'speed';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';
}
