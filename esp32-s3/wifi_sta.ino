#include "params.h"
#include "WiFiCredentials.h"

void activateWiFi_STA() {
  if (currentMode == MODE_WIFI_STA) return;

  WiFi.mode(WIFI_STA);
  WiFi.begin(STA_SSID, STA_PASS);

  Serial.print("\nConectando a WiFi");
  unsigned long t0 = millis();

  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
    if (millis() - t0 > 8000) {
      Serial.println("\nNo se pudo conectar");
      return;
    }
  }

  Serial.println("\nWiFi STA conectado");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  udp.begin(UDP_PORT);
  Serial.print("UDP escuchando en ");
  Serial.println(UDP_PORT);

  currentMode = MODE_WIFI_STA;
}