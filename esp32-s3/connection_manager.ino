#include "params.h"
#include <string.h>

static bool parseModeValue(const char* modeValue, Mode &outMode) {
  if (modeValue == nullptr) return false;

  if (strcmp(modeValue, "wifi_ap") == 0) {
    outMode = MODE_WIFI_AP;
    return true;
  }
  if (strcmp(modeValue, "ble") == 0) {
    outMode = MODE_BLE;
    return true;
  }
  return false;
}

void requestModeChange(const char* modeValue, const char* ssid, const char* pass) {
  Mode nextMode = MODE_NONE;
  if (!parseModeValue(modeValue, nextMode)) return;

  logTrace("INFO", "MODE", "requested temporary change -> %s", modeValue);
  pendingMode = nextMode;
  modeChangePending = true;
  modeChangeStartMs = millis();
  modeChangeDeadlineMs = millis() + ((nextMode == MODE_WIFI_AP && mainMode == MODE_BLE)
    ? WIFI_AP_RETURN_TO_BLE_MS
    : MODE_CHANGE_TIMEOUT_MS);
}

void requestMainModeChange(const char* modeValue, const char* ssid, const char* pass) {
  Mode nextMode = MODE_NONE;
  if (!parseModeValue(modeValue, nextMode)) return;

  logTrace("INFO", "MODE", "saved main mode -> %s", modeValue);
  saveMainMode(nextMode);
}

void activateMainMode() {
  switch (mainMode) {
    case MODE_BLE:
      logTrace("INFO", "MODE", "main mode -> BLE");
      activateBLE();
      break;
    case MODE_WIFI_AP:
    default:
      logTrace("INFO", "MODE", "main mode -> WiFi AP");
      activateWIFI_AP();
      break;
  }
}

void activateFallbackMode() {
  logTrace("WARN", "MODE", "fallback -> WiFi AP");
  activateWIFI_AP();
}

void applyPendingModeChange() {
  if (!modeChangePending || pendingMode == MODE_NONE) return;
  if (currentMode == pendingMode) return;

  if (pendingMode == MODE_WIFI_AP && currentMode == MODE_BLE && deviceConnected) {
    return;
  }

  switch (pendingMode) {
    case MODE_WIFI_AP:
      activateWIFI_AP();
      break;
    case MODE_BLE:
      activateBLE();
      break;
    default:
      break;
  }
}

void noteModeActivity(Mode mode) {
  if (!modeChangePending) return;
  if (currentMode != pendingMode) return;
  if (currentMode != mode) return;
  modeChangePending = false;
}
