# RC Controller App (TFG Controller App)

Cross-platform Flutter application to control an ESP32-based remote device (RC controller) developed as part of a university project.

## Table of contents

- Features
- Requirements
- Quick start
- Running on a device
- Building release packages
- ESP32 firmware (integration)
- Project structure
- Testing
- Contributing
- License

## Features

- Real-time remote control UI for an ESP32 device (BLE and UDP/Wi‑Fi transports).
- Settings persistence across app restarts
- Localization support (l10n)

## Requirements

- Flutter (stable) — see https://flutter.dev for install instructions
- Android SDK for building Android packages
- A supported device or emulator (Android) for running the app
- To integrate with hardware: Arduino/PlatformIO toolchain for flashing the ESP32-S3 firmware

## Quick start

1. Open a terminal in the `flutter_app` folder.
2. Install Dart/Flutter dependencies:

```bash
flutter pub get
```

3. Run the app on the connected device or emulator:

```bash
flutter run -d <device-id>
```

Replace `<device-id>` with the output of `flutter devices` or omit to use the default device.

## Running on a device

- Android: connect a device or start an emulator and run `flutter run`.

## Building release packages

- Android APK / AAB:

```bash
flutter build apk --release
flutter build appbundle --release
```

Follow platform-specific signing steps in upstream Flutter docs when preparing app store releases.

## ESP32 firmware (integration)

The firmware and ESP32-related sources live in the repository at `../esp32-s3` relative to this folder. To flash the device:

- Open the `esp32-s3` folder with Arduino IDE or PlatformIO.
- Select the appropriate board (ESP32-S3) and the correct serial/port.
- Build and upload to the device. The firmware implements the BLE, UDP and transport logic the app communicates with.

## Project structure

- `lib/` — main Flutter application code
	- `app.dart`, `main.dart` — app entrypoints
	- `features/` — feature modules and UI
	- `services/` — platform services, transport and connectivity logic
	- `transport/` — serialization and transport helpers
- `assets/` — images and icons used by the app
- `test/` — unit and widget tests
- `integration_test/` — end-to-end tests
- `ios/`, `android/`, `windows/` — platform projects

## Testing

Run unit and widget tests with:

```bash
flutter test
```

Run integration tests (requires a running device/emulator):

```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart
```

