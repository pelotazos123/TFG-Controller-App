#include <Preferences.h>
#include <string.h>
#include "params.h"

static const char* PREF_NAMESPACE = "rc_ctrl";
static const char* KEY_MAIN_MODE = "main_mode";

static const char* modeToString(Mode mode) {
  switch (mode) {
    case MODE_WIFI_AP:
      return "wifi_ap";
    case MODE_BLE:
      return "ble";
    default:
      return "wifi_ap";
  }
}

static bool modeFromString(const char* raw, Mode &outMode) {
  if (raw == nullptr || raw[0] == 0) return false;
  if (strcmp(raw, "wifi_ap") == 0) {
    outMode = MODE_WIFI_AP;
    return true;
  }
  if (strcmp(raw, "ble") == 0) {
    outMode = MODE_BLE;
    return true;
  }
  return false;
}

void loadPersistentSettings() {
  Preferences prefs;
  if (!prefs.begin(PREF_NAMESPACE, true)) return;

  String rawMode = prefs.getString(KEY_MAIN_MODE, "");
  Mode parsed;
  if (modeFromString(rawMode.c_str(), parsed)) {
    mainMode = parsed;
  }

  prefs.end();
}

void saveMainMode(Mode mode) {
  Preferences prefs;
  if (!prefs.begin(PREF_NAMESPACE, false)) return;

  prefs.putString(KEY_MAIN_MODE, modeToString(mode));
  prefs.end();
  mainMode = mode;
}
