#include <Arduino.h>
#include "params.h"
#include "esp_system.h"

Mode currentMode = MODE_NONE;
Mode mainMode = MODE_WIFI_AP;
static unsigned long lastModeActiveMs = 0;
static const unsigned long MODE_RECOVERY_MS = 3000;
bool modeChangePending = false;
Mode pendingMode = MODE_NONE;
unsigned long modeChangeStartMs = 0;
static const unsigned long MODE_CHANGE_TIMEOUT_MS = 30000;

void setup() {
  Serial.begin(115200);
  delay(1000);

  controlSetup();
  setupGPS();

  loadPersistentSettings();
  activateMainMode();
}

void loop() {
  gpsUpdate();

  applyPendingModeChange();

  unsigned long now = millis();
  if (currentMode != MODE_NONE) {
    lastModeActiveMs = now;
  } else if (lastModeActiveMs == 0) {
    lastModeActiveMs = now;
  } else if (now - lastModeActiveMs > MODE_RECOVERY_MS) {
    activateMainMode();
    lastModeActiveMs = now;
  }

  if (modeChangePending && now - modeChangeStartMs > MODE_CHANGE_TIMEOUT_MS) {
    modeChangePending = false;
    activateMainMode();
  }

  if (currentMode == MODE_WIFI_AP) {
    UDPtransport();
  } else if (currentMode == MODE_BLE) {
    BLEtransport();
  } else {
    tx = ty = sx = sy = 0.0f;
  }

  controlUpdate();
}