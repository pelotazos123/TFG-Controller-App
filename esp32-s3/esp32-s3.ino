#include <Arduino.h>
#include "params.h"
#include "esp_system.h"

Mode currentMode = MODE_NONE;
Mode mainMode = MODE_BLE;

float tx = 0.0f, ty = 0.0f, sx = 0.0f, sy = 0.0f;
float driveScale = 1.0f;
static unsigned long lastModeActiveMs = 0;
static const unsigned long MODE_RECOVERY_MS = 3000;
bool modeChangePending = false;
Mode pendingMode = MODE_NONE;
unsigned long modeChangeStartMs = 0;
unsigned long modeChangeDeadlineMs = 0;

static void forceMotorsOff() {
  pinMode(FRONT_IN1, OUTPUT);
  pinMode(FRONT_IN2, OUTPUT);
  pinMode(FRONT_IN3, OUTPUT);
  pinMode(FRONT_IN4, OUTPUT);
  pinMode(REAR_IN1, OUTPUT);
  pinMode(REAR_IN2, OUTPUT);
  pinMode(REAR_IN3, OUTPUT);
  pinMode(REAR_IN4, OUTPUT);

  pinMode(FRONT_ENA, OUTPUT);
  pinMode(FRONT_ENB, OUTPUT);
  pinMode(REAR_ENA, OUTPUT);
  pinMode(REAR_ENB, OUTPUT);

  digitalWrite(FRONT_IN1, LOW);
  digitalWrite(FRONT_IN2, LOW);
  digitalWrite(FRONT_IN3, LOW);
  digitalWrite(FRONT_IN4, LOW);
  digitalWrite(REAR_IN1, LOW);
  digitalWrite(REAR_IN2, LOW);
  digitalWrite(REAR_IN3, LOW);
  digitalWrite(REAR_IN4, LOW);

  digitalWrite(FRONT_ENA, LOW);
  digitalWrite(FRONT_ENB, LOW);
  digitalWrite(REAR_ENA, LOW);
  digitalWrite(REAR_ENB, LOW);
}

void setup() {
  forceMotorsOff();
  Serial.begin(115200);
  delay(1000);
  logTrace(
    "INFO",
    "START",
    "FW=TFG-Controller-App build=%s %s PWM=%dbit@%dHz AP=%s",
    __DATE__,
    __TIME__,
    PWM_RES,
    PWM_FREQ,
    SOFTAP_LOCAL_IP.toString().c_str()
  );

  controlSetup();

  loadPersistentSettings();
  activateMainMode();
}

void loop() {
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

  if (modeChangePending && modeChangeDeadlineMs != 0 && now > modeChangeDeadlineMs) {
    modeChangePending = false;
    logTrace("WARN", "MODE", "change timeout -> main mode");
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