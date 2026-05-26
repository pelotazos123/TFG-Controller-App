#include "params.h"

unsigned long lastPacketMs = 0;
WiFiUDP udp;

char packetBuffer[256];
float tx = 0, ty = 0, sx = 0, sy = 0;

static IPAddress controlEndpointIp;
static uint16_t controlEndpointPort = 0;
static bool hasControlEndpoint = false;
static unsigned long lastGpsSendMs = 0;
static const unsigned long GPS_SEND_MS = 1000;

static void updateControlEndpoint();

namespace {
const char* const HELLO_TYPE = "hello";
const char* const HELLO_ACK_TYPE = "hello_ack";

void logUdpRx(int packetSize) {
  if (!LOG_TRANSPORT_ENDPOINTS) return;
  Serial.printf(
    "UDP RX %d bytes from %s:%u\n",
    packetSize,
    udp.remoteIP().toString().c_str(),
    udp.remotePort()
  );
}

void logUdpPayload(const char* label, const char* payload, size_t len) {
  if (!LOG_TRANSPORT_MESSAGES) return;
  Serial.printf("UDP %s: ", label);
  Serial.write((const uint8_t*)payload, len);
  Serial.println();
}

bool readPacketPayload(int packetSize, int& payloadLen) {
  if (packetSize >= (int)sizeof(packetBuffer)) {
    int discarded = udp.read(packetBuffer, sizeof(packetBuffer));
    while (udp.available() > 0) {
      discarded += udp.read(packetBuffer, sizeof(packetBuffer));
    }
    if (LOG_TRANSPORT_MESSAGES) {
      Serial.printf(
        "UDP packet too large: %d bytes (max %u)\n",
        packetSize,
        (unsigned int)(sizeof(packetBuffer) - 1)
      );
    }
    payloadLen = 0;
    return false;
  }

  payloadLen = udp.read(packetBuffer, sizeof(packetBuffer) - 1);
  if (payloadLen <= 0) return false;
  packetBuffer[payloadLen] = 0;
  return true;
}

bool parseJsonPacket(StaticJsonDocument<JSON_RX_CAPACITY>& doc) {
  const DeserializationError err = deserializeJson(doc, packetBuffer);
  if (err == DeserializationError::Ok) {
    return true;
  }

  if (LOG_TRANSPORT_MESSAGES) {
    if (err == DeserializationError::NoMemory) {
      Serial.println("UDP JSON demasiado grande");
    } else {
      Serial.printf("UDP JSON invalido: %s | raw: %s\n", err.c_str(), packetBuffer);
    }
  }
  return false;
}

void sendHelloAck() {
  StaticJsonDocument<64> ack;
  ack["type"] = HELLO_ACK_TYPE;
  char out[64];
  const size_t outLen = serializeJson(ack, out, sizeof(out));
  udp.beginPacket(udp.remoteIP(), udp.remotePort());
  udp.write((uint8_t*)out, outLen);
  udp.endPacket();

  logUdpPayload("TX", out, outLen);
}

void onControlPacketApplied() {
  if (currentMode == MODE_WIFI_AP) {
    noteModeActivity(currentMode);
  }

  updateControlEndpoint();

  if (LOG_CONTROL_PACKETS) {
    Serial.printf("T(%.2f, %.2f) | S(%.2f, %.2f)\n", tx, ty, sx, sy);
  }
}

bool handleParsedPacket(JsonDocument& doc) {
  const char* msgType = doc["type"];
  if (msgType && strcmp(msgType, HELLO_TYPE) == 0) {
    updateControlEndpoint();
    if (currentMode == MODE_WIFI_AP) {
      noteModeActivity(currentMode);
    }

    sendHelloAck();
    return true;
  }

  if (handleModeCommand(doc)) {
    return true;
  }

  if (applyControlPacket(doc, lastPacketMs)) {
    onControlPacketApplied();
    return true;
  }

  return false;
}
}  // namespace

void udpResetControlEndpoint() {
  controlEndpointIp = IPAddress();
  controlEndpointPort = 0;
  hasControlEndpoint = false;
  lastGpsSendMs = 0;
  lastPacketMs = 0;
}

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

  logUdpPayload("TX", out, outLen);
}

void UDPtransport() {
  int packetSize = 0;
  while ((packetSize = udp.parsePacket()) > 0) {
    logUdpRx(packetSize);

    int payloadLen = 0;
    if (!readPacketPayload(packetSize, payloadLen)) continue;

    logUdpPayload("RX", packetBuffer, (size_t)payloadLen);

    StaticJsonDocument<JSON_RX_CAPACITY> doc;
    if (!parseJsonPacket(doc)) continue;
    handleParsedPacket(doc);
  }

  // Failsafe
  if (millis() - lastPacketMs > FAILSAFE_MS) {
    tx = ty = sx = sy = 0.0;
  }

  sendGpsTelemetryIfDue();
}