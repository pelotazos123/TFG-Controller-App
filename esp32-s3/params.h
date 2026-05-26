 #ifndef PARAMS_H
#define PARAMS_H

#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"

#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>

// ============================================================
// L298N Motor Driver Setup (2 drivers for 4 motors)
// Each L298N controls 2 motors via ENA/ENB (PWM) and IN1-IN4.
// ============================================================

// --- L298N Driver 1 (FRONT: front-left + front-right) ---
// Motor A = front-left, Motor B = front-right
const int FRONT_ENA = 45;   // PWM for front-left
const int FRONT_IN1 = 48;   // Direction pin 1 for front-left
const int FRONT_IN2 = 47;   // Direction pin 2 for front-left
const int FRONT_IN3 = 21;   // Direction pin 1 for front-right
const int FRONT_IN4 = 20;   // Direction pin 2 for front-right
const int FRONT_ENB = 19;   // PWM for front-right

// --- L298N Driver 2 (REAR: rear-left + rear-right) ---
// Motor A = rear-left, Motor B = rear-right
const int REAR_ENA = 40;   // PWM for rear-left
const int REAR_IN1 = 39;   // Direction pin 1 for rear-left
const int REAR_IN2 = 38;   // Direction pin 2 for rear-left
const int REAR_IN3 = 37;   // Direction pin 1 for rear-right
const int REAR_IN4 = 36;   // Direction pin 2 for rear-right
const int REAR_ENB = 35;   // PWM for rear-right


// ========= GPS (NEO-6M) =========
const int GPS_RX_PIN = 1;
const int GPS_TX_PIN = 2;
const uint32_t GPS_BAUD = 9600;

// ========= Mode button =========
const int PIN_BUTTON = 41;
const unsigned long MODE_BUTTON_DEBOUNCE_MS = 40;

// ========= BLE controller (HID host) =========
const char* BLE_CONTROLLER_NAME = "Wireless Controller";
const unsigned long BLE_CONTROLLER_CONNECT_TIMEOUT_MS = 50000;

// ========= Wi-Fi AP =========
const char AP_SSID[] = "ESP32_RC";
const char AP_PASS[] = "123456789";

// ========= UDP =========
extern WiFiUDP udp;
extern const int UDP_PORT = 4210;
void udpResetControlEndpoint();

// ========= JSON payload sizing =========
// Max lengths for incoming mode-change payloads.
constexpr size_t JSON_MAX_SSID_LEN = 32;
constexpr size_t JSON_MAX_PASS_LEN = 64;
constexpr size_t JSON_MAX_MODE_LEN = 8;

// Control packet: type + tx/ty/sx/sy.
constexpr size_t JSON_CONTROL_CAPACITY = JSON_OBJECT_SIZE(5) + 32;
// Mode packet: type + mode + ssid + pass.
constexpr size_t JSON_MODE_CAPACITY =
  JSON_OBJECT_SIZE(4) + JSON_MAX_MODE_LEN + JSON_MAX_SSID_LEN + JSON_MAX_PASS_LEN + 24;
// Shared RX capacity (largest expected inbound payload).
constexpr size_t JSON_RX_CAPACITY =
  (JSON_MODE_CAPACITY > JSON_CONTROL_CAPACITY)
    ? JSON_MODE_CAPACITY
    : JSON_CONTROL_CAPACITY;

// ========= Serial logging =========
// Set these to false to reduce Serial Monitor noise.
const bool LOG_TRANSPORT_MESSAGES = true;
const bool LOG_TRANSPORT_ENDPOINTS = true;
const bool LOG_CONTROL_PACKETS = false;

// ========= Timing =========
extern const unsigned long TIMEOUT_MS = 200;
extern const unsigned long FAILSAFE_MS = 300;
extern const unsigned long MODE_FALLBACK_MS = 45000;

// ========= Joystick =========
extern float tx;
extern float ty;
extern float sx;
extern float sy;

enum Mode {
  MODE_NONE,
  MODE_WIFI_AP,
  MODE_BLE,
  MODE_BLE_CONTROLLER
};

struct WheelTargets {
  float frontLeft;
  float frontRight;
  float rearLeft;
  float rearRight;
};

struct DirectionVector {
  float strafe;
  float forward;
  float rotate;
};

extern Mode currentMode;
extern Mode mainMode;
extern bool modeChangePending;
extern Mode pendingMode;
extern unsigned long modeChangeStartMs;
extern bool deviceConnected;
void applyPendingModeChange();

// ========= Connection modes =========
void activateWIFI_AP();
void activateBLE();
void stopBLE();
void activateBLEController();
void stopBLEController();
void activateMainMode();
void activateFallbackMode();
void requestModeChange(const char* modeValue, const char* ssid, const char* pass);
void requestMainModeChange(const char* modeValue, const char* ssid, const char* pass);
void noteModeActivity(Mode mode);

// ========= BLE stack =========
void ensureBleStackInitialized(const char* deviceName);

// ========= Persistent settings =========
void loadPersistentSettings();
void saveMainMode(Mode mode);

// ========= Transports =========
void UDPtransport();
void BLEtransport();
void BLEControllerTransport();

// ========= Transport JSON =========
bool handleModeCommand(JsonDocument& doc);
bool applyControlPacket(JsonDocument& doc, unsigned long& lastPacketMs);

// ========= GPS API =========
void setupGPS();
void gpsUpdate();
bool gpsHasValidFix();
double gpsLatitude();
double gpsLongitude();
double gpsAltitudeM();
double gpsSpeedKmph();
uint32_t gpsSatellites();
uint32_t gpsFixAgeMs();

#endif