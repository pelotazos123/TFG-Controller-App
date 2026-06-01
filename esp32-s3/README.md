ESP32-S3 firmware for the RC controller platform used in this project.

This firmware handles:
- Motor control (4 motors through 2x L298N)
- UDP control input from the Flutter app
- WiFi AP or BLE startup modes

## 1) Hardware setup

### 1.1 Main components
- ESP32-S3 development board
- 2x L298N motor driver boards
- 4 DC motors
- External power for motors (do not power motors from ESP32 3V3)

### 1.2 Motor driver pin map
Pins are defined in params.h.

Front driver (L298N #1):
- FRONT_ENA -> GPIO45
- FRONT_IN1 -> GPIO48
- FRONT_IN2 -> GPIO47
- FRONT_IN3 -> GPIO21
- FRONT_IN4 -> GPIO20
- FRONT_ENB -> GPIO19

Rear driver (L298N #2):
- REAR_ENA -> GPIO40
- REAR_IN1 -> GPIO39
- REAR_IN2 -> GPIO38
- REAR_IN3 -> GPIO37
- REAR_IN4 -> GPIO36
- REAR_ENB -> GPIO35

## 2) Software requirements

- Arduino IDE 2.x
- ESP32 board package (Espressif)
- Libraries:
	- ArduinoJson

Notes:
- WiFi and BLE headers used by this project come from the ESP32 core.
- If compilation fails on BLE includes, update the ESP32 board package to a recent version.

## 3) Firmware configuration

### 3.1 Startup network mode
In esp32-s3.ino, choose one startup mode in setup():

- AP mode (default): activateWIFI_AP();
- BLE mode: activateBLE();

Current default is BLE mode.

### 3.2 AP mode defaults
Defined in wifi_ap.ino:
- SSID: ESP32_RC
- Password: 123456789
- UDP port: 4210

### 3.3 BLE mode
- Device name: ESP32-BLE
- Service UUID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
- RX characteristic: 6E400002-B5A3-F393-E0A9-E50E24DCCA9E
- TX characteristic: 6E400003-B5A3-F393-E0A9-E50E24DCCA9E

## 4) Build and upload (Arduino IDE)

1. Open esp32-s3.ino from this folder.
2. Select board: ESP32S3 Dev Module (or your exact ESP32-S3 board).
3. Select the correct COM port.
4. Install missing libraries if prompted.
5. Upload.
6. Open Serial Monitor at 115200 baud.

Expected startup output (AP mode):
- WiFi AP created message
- AP IP address
- UDP listening on port 4210

## 5) Control protocol (UDP)

### 5.1 Handshake
Client can send:

{
	"type": "hello"
}

ESP32 responds with:

{
	"type": "hello_ack"
}

### 5.2 Control packet
Control values are read from:

{
	"tx": 0.0,
	"ty": 0.0,
	"sx": 0.0,
	"sy": 0.0
}

If packets stop arriving, failsafe sets all axes to zero after 300 ms.

## 6) Control protocol (BLE)

BLE uses the same JSON control shape as UDP for `tx`, `sx`, and `sy`.

## 7) Quick validation checklist

- Motors stay stopped at boot
- UDP control packets are visible on serial output
- Robot stops if app closes or packets are interrupted

## 8) Common issues

- No upload: verify board/port and USB cable (data cable, not charge-only)
- No UDP control: check phone/PC network and startup mode (AP vs BLE)
- No BLE control: ensure the device is bonded and Bluetooth is enabled
- Unstable motor behavior: verify driver wiring and common ground between ESP32 and motor driver supply