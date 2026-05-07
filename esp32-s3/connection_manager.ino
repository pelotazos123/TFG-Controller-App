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

  pendingMode = nextMode;
  modeChangePending = true;
  modeChangeStartMs = millis();
}

void requestMainModeChange(const char* modeValue, const char* ssid, const char* pass) {
  Mode nextMode = MODE_NONE;
  if (!parseModeValue(modeValue, nextMode)) return;

  saveMainMode(nextMode);
}

void activateMainMode() {
  switch (mainMode) {
    case MODE_BLE:
      activateBLE();
      break;
    case MODE_WIFI_AP:
    default:
      activateWIFI_AP();
      break;
  }
}

void activateFallbackMode() {
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
