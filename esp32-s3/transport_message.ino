#include "params.h"

#include <cstring>

namespace {
  const char* const KEY_TYPE = "type";
  const char* const KEY_MODE = "mode";
  const char* const KEY_SSID = "ssid";
  const char* const KEY_PASS = "pass";
  const char* const KEY_TX = "tx";
  const char* const KEY_TY = "ty";
  const char* const KEY_SX = "sx";
  const char* const KEY_SY = "sy";

  bool isMessageType(const char* msgType, const char* expected) {
    return (msgType != nullptr) && (strcmp(msgType, expected) == 0);
  }

  void readModePayload(
    JsonDocument& doc,
    const char*& modeValue,
    const char*& ssid,
    const char*& pass
  ) {
    modeValue = doc[KEY_MODE];
    ssid = doc[KEY_SSID];
    pass = doc[KEY_PASS];
  }

  bool handleModeRequest(JsonDocument& doc, bool asMainMode) {
    const char* modeValue = nullptr;
    const char* ssid = nullptr;
    const char* pass = nullptr;
    readModePayload(doc, modeValue, ssid, pass);

    if (asMainMode) {
      requestMainModeChange(modeValue, ssid, pass);
    } else {
      requestModeChange(modeValue, ssid, pass);
    }

    return true;
  }
}  

static const char* getMessageType(JsonDocument& doc) {
  return doc[KEY_TYPE];
}

bool handleModeCommand(JsonDocument& doc) {
  const char* msgType = getMessageType(doc);
  if (isMessageType(msgType, "set_mode")) {
    return handleModeRequest(doc, false);
  }

  if (isMessageType(msgType, "set_main_mode")) {
    return handleModeRequest(doc, true);
  }

  return false;
}

bool applyControlPacket(JsonDocument& doc, unsigned long& lastPacketMs) {
  const char* msgType = getMessageType(doc);
  if (!isMessageType(msgType, "control")) {
    return false;
  }

  tx = doc[KEY_TX] | 0.0;
  ty = doc[KEY_TY] | 0.0;
  sx = doc[KEY_SX] | 0.0;
  sy = doc[KEY_SY] | 0.0;
  lastPacketMs = millis();
  return true;
}
