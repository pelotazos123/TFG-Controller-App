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

// PWM config
const int PWM_FREQ = 1000;
const int PWM_RES = 8;  // 0-255
const int PWM_MAX = (1 << PWM_RES) - 1;

// Drive behavior
const float STRAFE_INPUT_SIGN = -1.0f;
const float THROTTLE_INPUT_SIGN = -1.0f;

// Minimum effective power where the car reliably moves.
const float MIN_EFFECTIVE_POWER = 0.45f;

// Use the same startup threshold on all wheels so standstill -> movement
// happens at the same instant. Set to 0.0 to disable instant boost.
const float START_CMD_ALL = 0.20f;

// Minimum PWM duty to apply when motor commanded (0..PWM_MAX)
const int MIN_DUTY_ALL = 80;

// Maximum speed change per wheel per millisecond (slew rate limiter).
// 0.008/ms → full reversal (-1 to +1) takes ~250 ms.
const float SLEW_RATE_PER_MS = 0.008f;

// Time in ms to hold a wheel at zero when a direction reversal is detected.
// Lets the motor spin down before reversing, avoiding back-EMF current spikes.
const unsigned long COAST_MS = 80;

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

// ========= Wi-Fi AP =========
const char AP_SSID[] = "ESP32_RC";
const char AP_PASS[] = "123456789";

// ========= BLE =========
const char BLE_DEVICE_NAME[] = "ESP32-BLE";

// ========= UDP =========
extern const int UDP_PORT = 4210;
void udpResetControlEndpoint();

// ========= JSON payload sizing =========
// Max lengths for incoming mode-change payloads.
constexpr size_t JSON_MAX_SSID_LEN = 32;
constexpr size_t JSON_MAX_PASS_LEN = 64;
constexpr size_t JSON_MAX_MODE_LEN = 8;

// Control packet: type + tx/ty/sx/sy + ds.
constexpr size_t JSON_CONTROL_CAPACITY = JSON_OBJECT_SIZE(6) + 40;
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

class BLECharacteristic;
extern WiFiUDP udp;
extern IPAddress controlEndpointIp;

extern uint16_t controlEndpointPort;
extern bool hasControlEndpoint;
extern BLECharacteristic* pTxCharacteristic;
extern bool deviceConnected;

void handleTerminalCommand(JsonDocument& doc);
void broadcastTrace(const char* level, const char* tag, const char* message);

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
  broadcastTrace(level, tag, buffer);
}

// ========= Timing =========
extern const unsigned long FAILSAFE_MS = 300;
extern const unsigned long BLE_FAILSAFE_MS = 700;
extern const unsigned long MODE_FALLBACK_MS = 45000;
extern const unsigned long MODE_CHANGE_TIMEOUT_MS = 30000;
extern const unsigned long WIFI_AP_RETURN_TO_BLE_MS = 30000;

// ========= Joystick =========
extern float tx;
extern float ty;
extern float sx;
extern float sy;
extern float driveScale;

enum Mode {
  MODE_NONE,
  MODE_WIFI_AP,
  MODE_BLE
};

extern Mode currentMode;
extern Mode mainMode;

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

extern bool modeChangePending;
extern Mode pendingMode;
extern unsigned long modeChangeStartMs;
extern unsigned long modeChangeDeadlineMs;
extern bool deviceConnected;
void applyPendingModeChange();

// ========= Connection modes =========
void activateWIFI_AP();
void activateBLE();
void stopBLE();
void activateMainMode();
void activateFallbackMode();
void requestModeChange(const char* modeValue, const char* ssid, const char* pass);
void requestMainModeChange(const char* modeValue);
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

#endif