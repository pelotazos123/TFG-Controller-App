#include "params.h"

unsigned long lastPacketMs = 0;
WiFiUDP udp;

char packetBuffer[128];
float tx = 0, ty = 0, sx = 0, sy = 0;

static IPAddress controlEndpointIp;
static uint16_t controlEndpointPort = 0;
static bool hasControlEndpoint = false;
static unsigned long lastGpsSendMs = 0;
static const unsigned long GPS_SEND_MS = 1000;

static void updateControlEndpoint() {
  controlEndpointIp = udp.remoteIP();
  controlEndpointPort = udp.remotePort();
  hasControlEndpoint = (controlEndpointPort != 0);
}

static void sendGpsTelemetryIfDue() {
  if (!hasControlEndpoint) return;

  unsigned long now = millis();
  if (now - lastGpsSendMs < GPS_SEND_MS) return;
  lastGpsSendMs = now;

  StaticJsonDocument<192> gpsDoc;
  gpsDoc["type"] = "gps";
  gpsDoc["valid"] = gpsHasValidFix();
  gpsDoc["lat"] = gpsLatitude();
  gpsDoc["lon"] = gpsLongitude();
  gpsDoc["alt"] = gpsAltitudeM();
  gpsDoc["speed"] = gpsSpeedKmph();
  gpsDoc["sat"] = gpsSatellites();
  gpsDoc["age"] = gpsFixAgeMs();

  char out[192];
  size_t outLen = serializeJson(gpsDoc, out, sizeof(out));
  udp.beginPacket(controlEndpointIp, controlEndpointPort);
  udp.write((uint8_t*)out, outLen);
  udp.endPacket();
}

void UDPtransport() {
  int packetSize = udp.parsePacket();
  if (packetSize) {
    int len = udp.read(packetBuffer, sizeof(packetBuffer) - 1);
    if (len > 0) packetBuffer[len] = 0;

    StaticJsonDocument<128> doc;
    if (deserializeJson(doc, packetBuffer) == DeserializationError::Ok) {
      const char* msgType = doc["type"];
      if (msgType && String(msgType) == "hello") {
        updateControlEndpoint();

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

  updateControlEndpoint();

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

  sendGpsTelemetryIfDue();
}