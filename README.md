# RControllerAPP

  RControllerAPP is a two-part remote control project for an ESP32-S3-based device:

- a Flutter app in `flutter_app/` for the user interface and transport layer
- an Arduino/ESP32 firmware project in `esp32-s3/` for the receiver, control logic, and motor handling

The app communicates with the firmware over BLE or Wi-Fi/UDP, depending on the selected mode.

## Project Structure

```text
.
├── flutter_app/   # Cross-platform Flutter application
└── esp32-s3/      # ESP32-S3 Arduino firmware
```

## What It Does

- Provides a mobile and desktop-friendly control interface for an ESP32-based RC platform
- Supports BLE control and Wi-Fi AP control with UDP transport
- Stores app settings locally so the last configuration can be reused after restart
- Controls a 4-motor drive system through the ESP32-S3 firmware

## Quick Start

### 1. Run the Flutter app

Open the Flutter project folder and install dependencies:

```bash
cd flutter_app
flutter pub get
flutter run
```

Useful build commands:

```bash
flutter test
flutter build apk --release
```

### 2. Flash the ESP32-S3 firmware

Open the firmware folder in Arduino IDE or another ESP32-compatible Arduino workflow:

```text
esp32-s3/
```

The firmware is built around the ESP32-S3 board package and uses Arduino libraries such as ArduinoJson.

## Connection Modes

The repository supports two main control paths:

- BLE, for direct Bluetooth control
- Wi-Fi AP with UDP, for local network control through the ESP32 soft AP

Default AP mode values used by the firmware are:

- SSID: `ESP32_RC`
- Password: `123456789`
- UDP port: `4210`

The Flutter app and firmware exchange control payloads that include joystick and motion values, plus a small handshake protocol for connection setup.

## Firmware Overview

The ESP32-S3 side handles:

- motor output for the 4-wheel drive system
- UDP control messages from the Flutter app
- BLE communication for wireless control
- startup and mode switching logic

## Recommended Workflow

1. Flash the ESP32-S3 firmware.
2. Start the Flutter app.
3. Choose the connection mode that matches the firmware configuration.
4. Test control input and verify the robot stops safely when input stops.

## Documentation

- API Documentation (GitHub Pages): https://pelotazos123.github.io/TFG-Controller-App/
- Flutter app details: [flutter_app/README.md](flutter_app/README.md)
- ESP32 firmware details: [esp32-s3/README.md](esp32-s3/README.md)

## Testing

The Flutter project includes unit, widget, and integration tests under `flutter_app/test/` and `flutter_app/integration_test/`.

## Notes

- The firmware and app are designed to work together, so keep transport and protocol changes in sync on both sides.
- For hardware setup, power the motors from an external supply and keep the ESP32 and motor driver grounds common.
