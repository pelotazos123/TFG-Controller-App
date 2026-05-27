 #ifndef PARAMS_H
#define PARAMS_H

#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>
#include <stdarg.h>
#include <stdio.h>

// ========= SoftAP IP configuration =========
// Default softAP IP (ESP32 WiFi softAP default is 192.168.4.1)
const IPAddress SOFTAP_LOCAL_IP(192, 168, 4, 1);
const IPAddress SOFTAP_GATEWAY(192, 168, 4, 1);
const IPAddress SOFTAP_SUBNET(255, 255, 255, 0);

// ========= Motor control tuning (defaults) =========
// These parameters control PWM, slew-rate, start thresholds and polarity.

// PWM config
const int PWM_FREQ = 1000;
const int PWM_RES = 8;  // 0-255
const int PWM_MAX = (1 << PWM_RES) - 1;

// Drive behavior
const float MOTOR_SLEW_RATE_PER_SEC = 10.0f; // full-scale units per second
const float STRAFE_INPUT_SIGN = -1.0f;
const float THROTTLE_INPUT_SIGN = -1.0f;

// Minimum effective power where the car reliably moves.
const float MIN_EFFECTIVE_POWER = 0.45f;

// Use the same startup threshold on all wheels so standstill -> movement
// happens at the same instant. Set to 0.0 to disable instant boost.
const float START_CMD_ALL = 0.20f;

// Minimum PWM duty to apply when motor commanded (0..PWM_MAX)
const int MIN_DUTY_ALL = 80;

// Motor polarity calibration. Set to -1.0 to invert a wheel.
const float DIR_FRONT_LEFT = 1.0f;
const float DIR_FRONT_RIGHT = 1.0f;
const float DIR_REAR_LEFT = 1.0f;
const float DIR_REAR_RIGHT = 1.0f;

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
const int GPS_RX_PIN = 42;
const int GPS_TX_PIN = 41;
const uint32_t GPS_BAUD = 9600;

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
const bool LOG_CONTROL_PACKETS = true;
const bool LOG_GPS_TRACES = true;

static inline void logTrace(const char* level, const char* tag, const char* fmt, ...) {
  unsigned long totalSeconds = millis() / 1000UL;
  unsigned long hours = totalSeconds / 3600UL;
  unsigned long minutes = (totalSeconds % 3600UL) / 60UL;
  unsigned long seconds = totalSeconds % 60UL;

  Serial.printf("[%02lu:%02lu:%02lu] %s %s: ", hours, minutes, seconds, level, tag);

  char buffer[256];
  va_list args;
  va_start(args, fmt);
  vsnprintf(buffer, sizeof(buffer), fmt, args);
  va_end(args);

  Serial.println(buffer);
}

// ========= Timing =========
extern const unsigned long TIMEOUT_MS = 200;
extern const unsigned long FAILSAFE_MS = 300;
extern const unsigned long MODE_FALLBACK_MS = 45000;
extern const unsigned long MODE_CHANGE_TIMEOUT_MS = 30000;
extern const unsigned long WIFI_AP_RETURN_TO_BLE_MS = 12000;

// ========= Joystick =========
extern float tx;
extern float ty;
extern float sx;
extern float sy;

enum Mode {
  MODE_NONE,
  MODE_WIFI_AP,
  MODE_BLE
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
extern unsigned long modeChangeDeadlineMs;
extern unsigned long modeTransitionHoldUntilMs;
extern bool deviceConnected;
void applyPendingModeChange();

// ========= Connection modes =========
void activateWIFI_AP();
void activateBLE();
void stopBLE();
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