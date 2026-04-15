#include <Arduino.h>
#include "params.h"

// Estado global
Mode currentMode = MODE_BLE;

// Botón
bool lastBtnState = HIGH;
unsigned long lastPressMs = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(PIN_BUTTON, INPUT_PULLUP);

  controlSetup();
  setupGPS();

  activateWIFI_AP();   // arranque por WiFi
  //activateWiFi_STA();
}

void loop() {
  bool btnState = digitalRead(PIN_BUTTON);

  if (btnState == LOW && lastBtnState == HIGH) {
    if (millis() - lastPressMs > DEBOUNCE_MS) {
      if (currentMode == MODE_WIFI_STA || currentMode == MODE_WIFI_AP) activateBLE();
      else activateWiFi_STA();
      lastPressMs = millis();
    }
  }

  lastBtnState = btnState;

  gpsUpdate();

  if (currentMode == MODE_WIFI_STA || currentMode == MODE_WIFI_AP) {
    UDPtransport();
  }

  controlUpdate();
}