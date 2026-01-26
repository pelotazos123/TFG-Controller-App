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

// ========= UDP =========
extern WiFiUDP udp;
extern const int UDP_PORT = 4210;

// ========= Timing =========
extern const unsigned long DEBOUNCE_MS = 250;
extern const unsigned long TIMEOUT_MS = 200;
extern const unsigned long FAILSAFE_MS = 200;

enum Mode {
  MODE_WIFI_AP,
  MODE_WIFI_STA,
  MODE_BLE
};

extern Mode currentMode;

#endif