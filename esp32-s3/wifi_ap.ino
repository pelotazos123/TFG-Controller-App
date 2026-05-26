#include <WiFi.h>
#include <ArduinoJson.h>
#include "params.h"

void activateWIFI_AP() {
  if (currentMode == MODE_WIFI_AP) return;

  stopBLE();
  stopBLEController();

  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  delay(300);

  Serial.println("WiFi AP creado");
  Serial.print("IP: ");
  Serial.println(WiFi.softAPIP());

  Serial.print("Clientes conectados: ");
  Serial.println(WiFi.softAPgetStationNum());

  udp.stop();
  udpResetControlEndpoint();
  if (udp.begin(UDP_PORT)) {
    Serial.print("UDP escuchando en puerto ");
    Serial.println(UDP_PORT);
  } else {
    Serial.println("ERROR al iniciar UDP en modo AP");
  }

  currentMode = MODE_WIFI_AP;
}

