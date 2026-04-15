ESP32-S3 controller code.

## GPS (NEO-6M)

This firmware now includes real-time GPS telemetry.

### Wiring

- NEO-6M VCC -> ESP32 3V3 (or 5V if your module requires it)
- NEO-6M GND -> ESP32 GND
- NEO-6M TX -> ESP32 GPIO16 (`GPS_RX_PIN`)
- NEO-6M RX -> ESP32 GPIO18 (`GPS_TX_PIN`, optional)

### Arduino dependency

Install library `TinyGPSPlus` from the Arduino Library Manager.

### UDP telemetry packet

When the app is connected over UDP, ESP32 sends one packet per second:

```json
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
```