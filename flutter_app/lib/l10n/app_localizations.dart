import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @connectionType.
  ///
  /// In en, this message translates to:
  /// **'Connection Type'**
  String get connectionType;

  /// No description provided for @wifi.
  ///
  /// In en, this message translates to:
  /// **'WiFi'**
  String get wifi;

  /// No description provided for @wifiAp.
  ///
  /// In en, this message translates to:
  /// **'WiFi AP'**
  String get wifiAp;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @bluetoothLe.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth LE'**
  String get bluetoothLe;

  /// No description provided for @bluetoothReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Make sure Bluetooth is enabled on your phone.'**
  String get bluetoothReminderBody;

  /// No description provided for @bluetoothOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get bluetoothOpenSettings;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @connectFirstToSwitch.
  ///
  /// In en, this message translates to:
  /// **'Connect to the controller first to switch modes.'**
  String get connectFirstToSwitch;

  /// No description provided for @esp32IpAddress.
  ///
  /// In en, this message translates to:
  /// **'ESP32 IP Address'**
  String get esp32IpAddress;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @pleaseEnterEsp32Ip.
  ///
  /// In en, this message translates to:
  /// **'Please enter ESP32 IP'**
  String get pleaseEnterEsp32Ip;

  /// No description provided for @udpConnected.
  ///
  /// In en, this message translates to:
  /// **'UDP Connected'**
  String get udpConnected;

  /// No description provided for @udpConnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'UDP connect timeout (no response from ESP32)'**
  String get udpConnectTimeout;

  /// No description provided for @failedToConnectUdp.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect UDP'**
  String get failedToConnectUdp;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLost;

  /// No description provided for @mainMode.
  ///
  /// In en, this message translates to:
  /// **'Main mode'**
  String get mainMode;

  /// No description provided for @mainModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use selected mode for next startup'**
  String get mainModeDescription;

  /// No description provided for @changeMode.
  ///
  /// In en, this message translates to:
  /// **'Change mode'**
  String get changeMode;

  /// No description provided for @controlSettings.
  ///
  /// In en, this message translates to:
  /// **'Control Settings'**
  String get controlSettings;

  /// No description provided for @maxDriveSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max Drive Speed'**
  String get maxDriveSpeed;

  /// No description provided for @reverseStrafeX.
  ///
  /// In en, this message translates to:
  /// **'Reverse Strafe (X)'**
  String get reverseStrafeX;

  /// No description provided for @leftJoystickHorizontalAxis.
  ///
  /// In en, this message translates to:
  /// **'Left joystick horizontal axis'**
  String get leftJoystickHorizontalAxis;

  /// No description provided for @reverseForwardBackY.
  ///
  /// In en, this message translates to:
  /// **'Reverse Forward/Back (Y)'**
  String get reverseForwardBackY;

  /// No description provided for @leftJoystickVerticalAxis.
  ///
  /// In en, this message translates to:
  /// **'Left joystick vertical axis'**
  String get leftJoystickVerticalAxis;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'App Name'**
  String get appName;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @hardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardware;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organization;

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'TRANSLATION'**
  String get translation;

  /// No description provided for @rotation.
  ///
  /// In en, this message translates to:
  /// **'ROTATION'**
  String get rotation;

  /// No description provided for @movementMatrix.
  ///
  /// In en, this message translates to:
  /// **'MOVEMENT MATRIX'**
  String get movementMatrix;

  /// No description provided for @hideMovementMatrix.
  ///
  /// In en, this message translates to:
  /// **'Hide movement matrix'**
  String get hideMovementMatrix;

  /// No description provided for @showMovementMatrix.
  ///
  /// In en, this message translates to:
  /// **'Show movement matrix'**
  String get showMovementMatrix;

  /// No description provided for @driveWheels.
  ///
  /// In en, this message translates to:
  /// **'Drive wheels'**
  String get driveWheels;

  /// No description provided for @twoWheels.
  ///
  /// In en, this message translates to:
  /// **'2 wheels'**
  String get twoWheels;

  /// No description provided for @fourWheels.
  ///
  /// In en, this message translates to:
  /// **'4 wheels'**
  String get fourWheels;

  /// No description provided for @useMecanumWheels.
  ///
  /// In en, this message translates to:
  /// **'Use mecanum wheels'**
  String get useMecanumWheels;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @rememberThis.
  ///
  /// In en, this message translates to:
  /// **'Remember this'**
  String get rememberThis;

  /// No description provided for @lockRotation.
  ///
  /// In en, this message translates to:
  /// **'Lock rotation'**
  String get lockRotation;

  /// No description provided for @unlockRotation.
  ///
  /// In en, this message translates to:
  /// **'Unlock rotation'**
  String get unlockRotation;

  /// No description provided for @moveForward.
  ///
  /// In en, this message translates to:
  /// **'Move forward'**
  String get moveForward;

  /// No description provided for @moveBackward.
  ///
  /// In en, this message translates to:
  /// **'Move backward'**
  String get moveBackward;

  /// No description provided for @moveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get moveLeft;

  /// No description provided for @moveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get moveRight;

  /// No description provided for @rotateRightCmd.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get rotateRightCmd;

  /// No description provided for @rotateLeftCmd.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get rotateLeftCmd;

  /// No description provided for @moveForwardLeft.
  ///
  /// In en, this message translates to:
  /// **'Move forward left'**
  String get moveForwardLeft;

  /// No description provided for @moveBackwardLeft.
  ///
  /// In en, this message translates to:
  /// **'Move backward left'**
  String get moveBackwardLeft;

  /// No description provided for @moveForwardRight.
  ///
  /// In en, this message translates to:
  /// **'Move forward right'**
  String get moveForwardRight;

  /// No description provided for @moveBackwardRight.
  ///
  /// In en, this message translates to:
  /// **'Move backward right'**
  String get moveBackwardRight;

  /// No description provided for @invalidIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IPv4 address'**
  String get invalidIpAddress;

  /// No description provided for @invalidPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid port (1-65535)'**
  String get invalidPort;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTitle;

  /// No description provided for @terminalNoTraffic.
  ///
  /// In en, this message translates to:
  /// **'No terminal traffic yet'**
  String get terminalNoTraffic;

  /// No description provided for @terminalCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get terminalCommand;

  /// No description provided for @terminalCommandHint.
  ///
  /// In en, this message translates to:
  /// **'help, status, ping, echo hello'**
  String get terminalCommandHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @terminalAutoscroll.
  ///
  /// In en, this message translates to:
  /// **'Autoscroll'**
  String get terminalAutoscroll;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
