#include <Arduino.h>
#include "params.h"

Mode currentMode = MODE_BLE;

void setup() {
  Serial.begin(115200);
  delay(1000);

  controlSetup();
  setupGPS();

  activateWIFI_AP();    // startup by WiFi Access Point (default mode)
  //activateWiFi_STA(); // startup by WiFi Station (connect to existing WiFi network)
}

void loop() {
  gpsUpdate();

  if (currentMode == MODE_WIFI_STA || currentMode == MODE_WIFI_AP) {
    UDPtransport();
  } else {
    //TODO: BLE transport
    tx = ty = sx = sy = 0.0f;
  }

  controlUpdate();
}