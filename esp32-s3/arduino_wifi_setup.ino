#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>

// ================== CONFIG ==================
//const char* WIFI_SSID = "ESP32_RC";
//const char* WIFI_PASS = "12345678";

WiFiUDP udp;
const int UDP_PORT = 4210;

const unsigned long TIMEOUT_MS = 200;
// ============================================

const unsigned long FAILSAFE_MS = 200;
unsigned long lastPacketMs = 0;

// ============================================

char packetBuffer[128];

// Control values
float tx = 0.0;
float ty = 0.0;
float sx = 0.0;
float sy = 0.0;


void setup() {
  Serial.begin(115200);
  delay(1000);

  // Start WiFi Access Point
  //WiFi.softAP(WIFI_SSID, WIFI_PASS);
  //IPAddress ip = WiFi.softAPIP();
  
  //Serial.println("ESP32 RC Controller");
  //Serial.print("AP IP: ");
  //Serial.println(ip); 

  // Connect to House WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASS); 
  Serial.print("Conectando a WiFi");

  uint status = WiFi.waitForConnectResult();

  while (status != WL_CONNECTED){
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi conectado");
  Serial.print("IP ESP32: ");
  Serial.print(WiFi.localIP());

  // Start UDP
  udp.begin(UDP_PORT);
  Serial.print("\nListening UDP on port: ");
  Serial.println(UDP_PORT);
}

void loop() {
  int packetSize = udp.parsePacket();
  if (packetSize) {
    int len = udp.read(packetBuffer, sizeof(packetBuffer) - 1);
    if (len > 0) packetBuffer[len] = 0;

    StaticJsonDocument<128> doc;
    if (deserializeJson(doc, packetBuffer) == DeserializationError::Ok) {
      tx = doc["tx"];
      ty = doc["ty"];
      sx = doc["sx"];
      sy = doc["sy"];

      lastPacketMs = millis();

      Serial.printf(
        "T(%.2f, %.2f) | S(%.2f, %.2f)\n",
        tx, ty, sx, sy
      );
    }
  }

  // Failsafe
  if (millis() - lastPacketMs > FAILSAFE_MS) {
    tx = ty = sx = sy = 0.0;
  }
}

