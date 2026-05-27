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

static int lastButtonReading = HIGH;
static int stableButtonState = HIGH;
static bool buttonLatched = false;
static unsigned long lastButtonDebounceMs = 0;

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

static void setupModeButton() {
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  stableButtonState = digitalRead(PIN_BUTTON);
  lastButtonReading = stableButtonState;
  lastButtonDebounceMs = millis();
  buttonLatched = (stableButtonState == LOW);
  Serial.printf("Mode button on GPIO %d (INPUT_PULLUP)\n", PIN_BUTTON);
}

static void toggleMainMode() {
  modeChangePending = false;
  pendingMode = MODE_NONE;

  Mode nextMode = (mainMode == MODE_WIFI_AP) ? MODE_BLE : MODE_WIFI_AP;
  Serial.println("Button: toggle main mode");
  saveMainMode(nextMode);
  activateMainMode();
}

static void handleModeButton() {
  int reading = digitalRead(PIN_BUTTON);
  if (reading != lastButtonReading) {
    lastButtonDebounceMs = millis();
    lastButtonReading = reading;
  }

  if (millis() - lastButtonDebounceMs < MODE_BUTTON_DEBOUNCE_MS) {
    return;
  }

  if (reading != stableButtonState) {
    stableButtonState = reading;
  }

  if (stableButtonState == LOW && !buttonLatched) {
    buttonLatched = true;
    toggleMainMode();
  } else if (stableButtonState == HIGH && buttonLatched) {
    buttonLatched = false;
  }
}

void setup() {
  forceMotorsOff();
  Serial.begin(115200);
  delay(1000);
  Serial.println("ESP32-S3 boot");

  controlSetup();
  setupGPS();
  setupModeButton();

  loadPersistentSettings();
  activateMainMode();
}

void loop() {
  gpsUpdate();
  handleModeButton();

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
    Serial.println("Mode change timeout -> main mode");
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