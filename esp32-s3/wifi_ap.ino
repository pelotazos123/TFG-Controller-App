#include <WiFi.h>
#include <ArduinoJson.h>
#include "params.h"

void activateWIFI_AP() {
  if (currentMode == MODE_WIFI_AP) return;

  stopBLE();

  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(SOFTAP_LOCAL_IP, SOFTAP_GATEWAY, SOFTAP_SUBNET);
  WiFi.softAP(AP_SSID, AP_PASS);
  delay(300);

  logTrace(
    "INFO",
    "WIFI",
    "SoftAP up SSID=%s IP=%s GW=%s MASK=%s clients=%u",
    AP_SSID,
    WiFi.softAPIP().toString().c_str(),
    SOFTAP_GATEWAY.toString().c_str(),
    SOFTAP_SUBNET.toString().c_str(),
    (unsigned int)WiFi.softAPgetStationNum()
  );

  udp.stop();
  udpResetControlEndpoint();
  if (udp.begin(UDP_PORT)) {
    logTrace("INFO", "UDP", "listening on port %d", UDP_PORT);
  } else {
    logTrace("ERROR", "UDP", "failed to start in AP mode");
  }

  currentMode = MODE_WIFI_AP;
}

