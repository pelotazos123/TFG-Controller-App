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
  String get back => 'Back';

  @override
  String get connection => 'Connection';

  @override
  String get connectionType => 'Connection Type';

  @override
  String get wifi => 'WiFi';

  @override
  String get wifiAp => 'WiFi AP';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get bluetoothLe => 'Bluetooth LE';

  @override
  String get bluetoothReminderBody =>
      'Make sure Bluetooth is enabled on your phone.';

  @override
  String get bluetoothOpenSettings => 'Open settings';

  @override
  String get ok => 'OK';

  @override
  String get connectFirstToSwitch =>
      'Connect to the controller first to switch modes.';

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
  String get mainMode => 'Main mode';

  @override
  String get mainModeDescription => 'Use selected mode for next startup';

  @override
  String get changeMode => 'Change mode';

  @override
  String get controlSettings => 'Control Settings';

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
  String get showTelemetry => 'Show telemetry';

  @override
  String get showTelemetryDescription =>
      'Show GPS telemetry on the control screen';

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
  String get driveWheels => 'Drive wheels';

  @override
  String get twoWheels => '2 wheels';

  @override
  String get fourWheels => '4 wheels';

  @override
  String get useMecanumWheels => 'Use mecanum wheels';

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

  @override
  String get rememberThis => 'Remember this';

  @override
  String get lockRotation => 'Lock rotation';

  @override
  String get unlockRotation => 'Unlock rotation';

  @override
  String get preparingControllerInterface =>
      'Preparing your controller interface';

  @override
  String get moveForward => 'Move forward';

  @override
  String get moveBackward => 'Move backward';

  @override
  String get moveLeft => 'Move left';

  @override
  String get moveRight => 'Move right';

  @override
  String get rotateRightCmd => 'Rotate right';

  @override
  String get rotateLeftCmd => 'Rotate left';

  @override
  String get moveForwardLeft => 'Move forward left';

  @override
  String get moveBackwardLeft => 'Move backward left';

  @override
  String get moveForwardRight => 'Move forward right';

  @override
  String get moveBackwardRight => 'Move backward right';

  @override
  String get invalidIpAddress => 'Enter a valid IPv4 address';

  @override
  String get invalidPort => 'Enter a valid port (1-65535)';
}
