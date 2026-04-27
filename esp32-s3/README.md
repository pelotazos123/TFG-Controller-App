ESP32-S3 firmware for the RC controller platform used in this project.

This firmware handles:
- Motor control (4 motors through 2x L298N)
- UDP control input from the Flutter app
- GPS telemetry (NEO-6M)
- WiFi AP or WiFi STA startup modes

## 1) Hardware setup

### 1.1 Main components
- ESP32-S3 development board
- 2x L298N motor driver boards
- 4 DC motors
- NEO-6M GPS module
- External power for motors (do not power motors from ESP32 3V3)

### 1.2 GPS wiring (NEO-6M)
- NEO-6M VCC -> ESP32 3V3 (or 5V if your module requires it)
- NEO-6M GND -> ESP32 GND
- NEO-6M TX -> ESP32 GPIO16 (GPS_RX_PIN)
- NEO-6M RX -> ESP32 GPIO18 (GPS_TX_PIN)

### 1.3 Motor driver pin map
Pins are defined in params.h.

Front driver (L298N #1):
- FRONT_ENA -> GPIO4
- FRONT_IN1 -> GPIO5
- FRONT_IN2 -> GPIO6
- FRONT_IN3 -> GPIO7
- FRONT_IN4 -> GPIO8
- FRONT_ENB -> GPIO9

Rear driver (L298N #2):
- REAR_ENA -> GPIO10
- REAR_IN1 -> GPIO11
- REAR_IN2 -> GPIO12
- REAR_IN3 -> GPIO13
- REAR_IN4 -> GPIO14
- REAR_ENB -> GPIO15

## 2) Software requirements

- Arduino IDE 2.x
- ESP32 board package (Espressif)
- Libraries:
	- TinyGPSPlus
	- ArduinoJson

Notes:
- WiFi and BLE headers used by this project come from the ESP32 core.
- If compilation fails on BLE includes, update the ESP32 board package to a recent version.

## 3) Firmware configuration

### 3.1 Startup network mode
In esp32-s3.ino, choose one startup mode in setup():

- AP mode (default): activateWIFI_AP();
- STA mode: activateWiFi_STA();

Current default is AP mode.

### 3.2 AP mode defaults
Defined in wifi_ap.ino:
- SSID: ESP32_RC
- Password: 12345678
- UDP port: 4210

### 3.3 STA mode credentials
Defined in WiFiCredentials.h:
- STA_SSID
- STA_PASS

Edit those values before upload if using STA mode.

## 4) Build and upload (Arduino IDE)

1. Open esp32-s3.ino from this folder.
2. Select board: ESP32S3 Dev Module (or your exact ESP32-S3 board).
3. Select the correct COM port.
4. Install missing libraries if prompted.
5. Upload.
6. Open Serial Monitor at 115200 baud.

Expected startup output (AP mode):
- GPS initialized message
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

### 5.3 GPS telemetry packet
Sent once per second to the active control endpoint:

{
	"type": "gps",
	"valid": true,
	"lat": 40.416775,
	"lon": -3.703790,
	"alt": 680.2,
	"speed": 1.4,
	"sat": 8,
	"age": 520
}

## 6) Quick validation checklist

- Motors stay stopped at boot
- UDP control packets are visible on serial output
- Robot stops if app closes or packets are interrupted
- GPS valid field changes to true when fix is available

## 7) Common issues

- No upload: verify board/port and USB cable (data cable, not charge-only)
- No GPS data: verify TX/RX wiring and antenna visibility to open sky
- No UDP control: check phone/PC network and startup mode (AP vs STA)
- Unstable motor behavior: verify driver wiring and common ground between ESP32 and motor driver supply