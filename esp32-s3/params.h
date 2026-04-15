 #ifndef PARAMS_H
#define PARAMS_H

#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"

#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>

#define PIN_BUTTON 17

// ============================================================
// L298N Motor Driver Setup (2 drivers for 4 motors)
// Each L298N controls 2 motors via ENA/ENB (PWM) and IN1-IN4.
// ============================================================

// --- L298N Driver 1 (FRONT: front-left + front-right) ---
// Motor A = front-left, Motor B = front-right
const int FRONT_ENA = 4;   // PWM for front-left
const int FRONT_IN1 = 5;   // Direction pin 1 for front-left
const int FRONT_IN2 = 6;   // Direction pin 2 for front-left
const int FRONT_IN3 = 7;   // Direction pin 1 for front-right
const int FRONT_IN4 = 8;   // Direction pin 2 for front-right
const int FRONT_ENB = 9;   // PWM for front-right

// --- L298N Driver 2 (REAR: rear-left + rear-right) ---
// Motor A = rear-left, Motor B = rear-right
const int REAR_ENA = 10;   // PWM for rear-left
const int REAR_IN1 = 11;   // Direction pin 1 for rear-left
const int REAR_IN2 = 12;   // Direction pin 2 for rear-left
const int REAR_IN3 = 13;   // Direction pin 1 for rear-right
const int REAR_IN4 = 14;   // Direction pin 2 for rear-right
const int REAR_ENB = 15;   // PWM for rear-right

// PWM channels
const int CH_FRONT_LEFT = 0;
const int CH_FRONT_RIGHT = 1;
const int CH_REAR_LEFT = 2;
const int CH_REAR_RIGHT = 3;

// ========= GPS (NEO-6M) =========
// GPS TX -> ESP32 RX pin. GPS RX is optional for this project.
const int GPS_RX_PIN = 16;
const int GPS_TX_PIN = 17;
const uint32_t GPS_BAUD = 9600;

// ========= UDP =========
extern WiFiUDP udp;
extern const int UDP_PORT = 4210;

// ========= Timing =========
extern const unsigned long DEBOUNCE_MS = 250;
extern const unsigned long TIMEOUT_MS = 200;
extern const unsigned long FAILSAFE_MS = 200;

// ========= Joystick =========
extern float tx;
extern float ty;
extern float sx;
extern float sy;

enum Mode {
  MODE_WIFI_AP,
  MODE_WIFI_STA,
  MODE_BLE
};

extern Mode currentMode;

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