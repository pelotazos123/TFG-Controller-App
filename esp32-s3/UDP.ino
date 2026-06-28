#include "params.h"

unsigned long lastPacketMs = 0;
WiFiUDP udp;

char packetBuffer[256];

IPAddress controlEndpointIp;
uint16_t controlEndpointPort = 0;
bool hasControlEndpoint = false;
IPAddress lastPacketIp;
uint16_t lastPacketPort = 0;
static unsigned long udpSessionStartMs = 0;
static unsigned long udpPacketCount = 0;
static unsigned long udpHelloCount = 0;
static unsigned long udpHelloAckCount = 0;
static bool udpFailsafeActive = false;

static void updateControlEndpoint();

namespace {
  const char* const HELLO_TYPE = "hello";
  const char* const HELLO_ACK_TYPE = "hello_ack";

  void logUdpRx(int packetSize) {
    if (!LOG_TRANSPORT_ENDPOINTS) return;
    logTrace(
      "DEBUG",
      "UDP",
      "rx %d bytes from %s:%u",
      packetSize,
      lastPacketIp.toString().c_str(),
      lastPacketPort
    );
  }

  void logUdpPayload(const char* label, const char* payload, size_t len) {
    if (!LOG_TRANSPORT_MESSAGES) return;
    logTrace("DEBUG", "UDP", "%s payload (%u bytes): %.*s", label, (unsigned int)len, (int)len, payload);
  }

  bool readPacketPayload(int packetSize, int& payloadLen) {
    if (packetSize >= (int)sizeof(packetBuffer)) {
      int discarded = udp.read(packetBuffer, sizeof(packetBuffer));
      while (udp.available() > 0) {
        discarded += udp.read(packetBuffer, sizeof(packetBuffer));
      }
      if (LOG_TRANSPORT_MESSAGES) {
        logTrace("WARN", "UDP", "packet too large: %d bytes (max %u)", packetSize, (unsigned int)(sizeof(packetBuffer) - 1));
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
        logTrace("WARN", "UDP", "JSON too large");
      } else {
        logTrace("WARN", "UDP", "JSON parse error: %s -> %.80s", err.c_str(), packetBuffer);
      }
    }
    return false;
  }

  void sendHelloAck() {
    StaticJsonDocument<64> ack;
    ack["type"] = HELLO_ACK_TYPE;
    ack["server_ms"] = millis();
    char out[64];
    const size_t outLen = serializeJson(ack, out, sizeof(out));
    udp.beginPacket(lastPacketIp, lastPacketPort);
    udp.write((uint8_t*)out, outLen);
    udp.endPacket();

    udpHelloAckCount++;
    logTrace(
      "INFO",
      "UDP",
      "hello ack sent session=%lums hello=%lu ack=%lu packets=%lu",
      (unsigned long)(millis() - udpSessionStartMs),
      udpHelloCount,
      udpHelloAckCount,
      udpPacketCount
    );
  }

  void onControlPacketApplied() {
    if (currentMode == MODE_WIFI_AP) {
      noteModeActivity(currentMode);
    }

    updateControlEndpoint();

    if (LOG_CONTROL_PACKETS) {
      logTrace(
        "INFO",
        "CONTROL",
        "intent peer=%s:%u tx=%.2f ty=%.2f sx=%.2f sy=%.2f",
        controlEndpointIp.toString().c_str(),
        controlEndpointPort,
        tx,
        ty,
        sx,
        sy
      );
    }
  }

  bool handleParsedPacket(JsonDocument& doc) {
    const char* msgType = doc["type"];
    if (msgType && strcmp(msgType, HELLO_TYPE) == 0) {
      udpHelloCount++;
      updateControlEndpoint();
      logTrace(
        "INFO",
        "UDP",
        "hello from %s:%u",
        controlEndpointIp.toString().c_str(),
        controlEndpointPort
      );
      if (currentMode == MODE_WIFI_AP) {
        noteModeActivity(currentMode);
      }

      sendHelloAck();
      return true;
    }

    if (msgType && strcmp(msgType, "terminal") == 0) {
      handleTerminalCommand(doc);
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
}

void udpResetControlEndpoint() {
  controlEndpointIp = IPAddress();
  controlEndpointPort = 0;
  hasControlEndpoint = false;
  lastPacketMs = millis();
  udpFailsafeActive = false;
  udpSessionStartMs = millis();
  udpPacketCount = 0;
  udpHelloCount = 0;
  udpHelloAckCount = 0;
}

static void updateControlEndpoint() {
  controlEndpointIp = lastPacketIp;
  controlEndpointPort = lastPacketPort;
  hasControlEndpoint = (controlEndpointPort != 0);
}

void UDPtransport() {
  int packetSize = 0;
  while ((packetSize = udp.parsePacket()) > 0) {
    lastPacketIp = udp.remoteIP();
    lastPacketPort = udp.remotePort();
    logUdpRx(packetSize);
    udpPacketCount++;

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
    if (!udpFailsafeActive) {
      udpFailsafeActive = true;
      logTrace("WARN", "FS", "no control packet for %lu ms -> zero outputs", (unsigned long)(millis() - lastPacketMs));
    }
  } else if (udpFailsafeActive) {
    udpFailsafeActive = false;
    logTrace("INFO", "FS", "control recovered after timeout");
  }

}