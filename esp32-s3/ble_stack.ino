#include "params.h"

static bool bleStackInitialized = false;

void ensureBleStackInitialized(const char* deviceName) {
  if (bleStackInitialized) return;

  BLEDevice::init(deviceName);
  BLEDevice::setMTU(185);
  BLEDevice::setPower(ESP_PWR_LVL_P9);

  bleStackInitialized = true;
}
