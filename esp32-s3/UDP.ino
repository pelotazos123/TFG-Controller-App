#include "params.h"

unsigned long lastPacketMs = 0;
WiFiUDP udp;

char packetBuffer[128];
float tx = 0, ty = 0, sx = 0, sy = 0;

void UDPtransport() {
  int packetSize = udp.parsePacket();
  if (packetSize) {
    int len = udp.read(packetBuffer, sizeof(packetBuffer) - 1);
    if (len > 0) packetBuffer[len] = 0;

    StaticJsonDocument<128> doc;
    if (deserializeJson(doc, packetBuffer) == DeserializationError::Ok) {
      const char* msgType = doc["type"];
      if (msgType && String(msgType) == "hello") {
        StaticJsonDocument<64> ack;
        ack["type"] = "hello_ack";
        char out[64];
        size_t outLen = serializeJson(ack, out, sizeof(out));
        udp.beginPacket(udp.remoteIP(), udp.remotePort());
        udp.write((uint8_t*)out, outLen);
        udp.endPacket();
        return;
      }


      tx = doc["tx"] | 0.0;
      ty = doc["ty"] | 0.0;
      sx = doc["sx"] | 0.0;
      sy = doc["sy"] | 0.0;

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