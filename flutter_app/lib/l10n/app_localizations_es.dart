// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get back => 'Atrás';

  @override
  String get connection => 'Conexión';

  @override
  String get connectionType => 'Tipo de conexión';

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
      'Asegúrate de que el Bluetooth esté activado en tu teléfono.';

  @override
  String get bluetoothOpenSettings => 'Abrir ajustes';

  @override
  String get ok => 'Aceptar';

  @override
  String get connectFirstToSwitch =>
      'Conéctate primero al controlador para cambiar de modo.';

  @override
  String get esp32IpAddress => 'Dirección IP del ESP32';

  @override
  String get port => 'Puerto';

  @override
  String get pleaseEnterEsp32Ip => 'Introduce la IP del ESP32';

  @override
  String get udpConnected => 'UDP conectado';

  @override
  String get udpConnectTimeout =>
      'Tiempo de espera agotado al conectar por UDP (sin respuesta del ESP32)';

  @override
  String get failedToConnectUdp => 'Error al conectar por UDP';

  @override
  String get connecting => 'Conectando...';

  @override
  String get connect => 'Conectar';

  @override
  String get connected => 'Conectado';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get connectionLost => 'Conexión perdida';

  @override
  String get mainMode => 'Modo principal';

  @override
  String get mainModeDescription =>
      'Usar el modo seleccionado en el próximo inicio';

  @override
  String get changeMode => 'Cambiar modo';

  @override
  String get controlSettings => 'Ajustes de control';

  @override
  String get maxDriveSpeed => 'Velocidad máxima';

  @override
  String get reverseStrafeX => 'Invertir desplazamiento lateral (X)';

  @override
  String get leftJoystickHorizontalAxis =>
      'Eje horizontal del joystick izquierdo';

  @override
  String get reverseForwardBackY => 'Invertir avance/retroceso (Y)';

  @override
  String get leftJoystickVerticalAxis => 'Eje vertical del joystick izquierdo';

  @override
  String get showTelemetry => 'Mostrar telemetria';

  @override
  String get showTelemetryDescription =>
      'Mostrar telemetria GPS en la pantalla de control';

  @override
  String get appearance => 'Apariencia';

  @override
  String get theme => 'Tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get about => 'Acerca de';

  @override
  String get appName => 'Nombre de la app';

  @override
  String get version => 'Versión';

  @override
  String get hardware => 'Hardware';

  @override
  String get developer => 'Desarrollador';

  @override
  String get organization => 'Organización';

  @override
  String get translation => 'TRASLACIÓN';

  @override
  String get rotation => 'ROTACIÓN';

  @override
  String get movementMatrix => 'MATRIZ DE MOVIMIENTO';

  @override
  String get hideMovementMatrix => 'Ocultar matriz de movimiento';

  @override
  String get showMovementMatrix => 'Mostrar matriz de movimiento';

  @override
  String get driveWheels => 'Ruedas de tracción';

  @override
  String get twoWheels => '2 ruedas';

  @override
  String get fourWheels => '4 ruedas';

  @override
  String get useMecanumWheels => 'Usar ruedas mecanum';

  @override
  String get gpsWaiting => 'GPS: esperando telemetría...';

  @override
  String get gpsFix => 'FIX';

  @override
  String get gpsNoFix => 'SIN FIX';

  @override
  String get gpsLatLabel => 'lat';

  @override
  String get gpsLonLabel => 'lon';

  @override
  String get gpsSatLabel => 'sat';

  @override
  String get gpsSpeedLabel => 'vel';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get rememberThis => 'Recordar esto';

  @override
  String get lockRotation => 'Bloquear rotación';

  @override
  String get unlockRotation => 'Desbloquear rotación';

  @override
  String get moveForward => 'Avanzar';

  @override
  String get moveBackward => 'Retroceder';

  @override
  String get moveLeft => 'Mover a la izquierda';

  @override
  String get moveRight => 'Mover a la derecha';

  @override
  String get rotateRightCmd => 'Girar a la derecha';

  @override
  String get rotateLeftCmd => 'Girar a la izquierda';

  @override
  String get moveForwardLeft => 'Avanzar a la izquierda';

  @override
  String get moveBackwardLeft => 'Retroceder a la izquierda';

  @override
  String get moveForwardRight => 'Avanzar a la derecha';

  @override
  String get moveBackwardRight => 'Retroceder a la derecha';

  @override
  String get invalidIpAddress => 'Introduce una direccion IPv4 valida';

  @override
  String get invalidPort => 'Introduce un puerto valido (1-65535)';
}
