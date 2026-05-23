#include "params.h"
#include <Arduino.h>
#include <string>

static const BLEUUID HID_SERVICE_UUID((uint16_t)0x1812);
static const BLEUUID HID_REPORT_UUID((uint16_t)0x2A4D);

static BLEClient* controllerClient = nullptr;
static BLERemoteCharacteristic* controllerReportChar = nullptr;
static BLEAdvertisedDevice* controllerAdvertised = nullptr;

static bool controllerConnected = false;
static bool controllerConnecting = false;
static unsigned long controllerModeStartMs = 0;
static unsigned long lastControllerPacketMs = 0;
static unsigned long lastConnectAttemptMs = 0;
static const unsigned long CONTROLLER_RETRY_MS = 2500;

static float clampAxis(float value) {
  if (value > 1.0f) return 1.0f;
  if (value < -1.0f) return -1.0f;
  return value;
}

static float normalizeAxis(uint8_t value) {
  return ((int)value - 128) / 127.0f;
}

static void handleControllerReport(const uint8_t* data, size_t length) {
  if (data == nullptr || length < 4) return;

  size_t offset = 0;
  if (length >= 5 && data[0] == 0x01) {
    offset = 1;
  }
  if (length < offset + 4) return;

  float lx = normalizeAxis(data[offset]);
  float ly = normalizeAxis(data[offset + 1]);
  float rx = normalizeAxis(data[offset + 2]);

  tx = clampAxis(lx);
  sy = clampAxis(-ly);
  sx = clampAxis(rx);
  ty = 0.0f;

  lastControllerPacketMs = millis();
}

static void controllerNotifyCallback(
  BLERemoteCharacteristic*,
  uint8_t* data,
  size_t length,
  bool
) {
  handleControllerReport(data, length);
}

class ControllerClientCallbacks : public BLEClientCallbacks {
  void onConnect(BLEClient*) override {
    controllerConnected = true;
    Serial.println("BLE controller connected");
  }

  void onDisconnect(BLEClient*) override {
    controllerConnected = false;
    controllerReportChar = nullptr;
    Serial.println("BLE controller disconnected");
  }
};

class ControllerAdvertisedCallbacks : public BLEAdvertisedDeviceCallbacks {
  void onResult(BLEAdvertisedDevice advertisedDevice) override {
    bool nameMatch = false;
    if (BLE_CONTROLLER_NAME != nullptr && BLE_CONTROLLER_NAME[0] != '\0') {
      String name = advertisedDevice.getName();
      nameMatch = (name == BLE_CONTROLLER_NAME);
    }

    bool hidService = advertisedDevice.haveServiceUUID() &&
        advertisedDevice.isAdvertisingService(HID_SERVICE_UUID);

    if (!nameMatch && !hidService) return;

    if (controllerAdvertised != nullptr) {
      delete controllerAdvertised;
    }
    controllerAdvertised = new BLEAdvertisedDevice(advertisedDevice);
    Serial.printf(
      "BLE controller candidate: %s\n",
      advertisedDevice.getName().c_str()
    );
    BLEDevice::getScan()->stop();
  }
};

static ControllerClientCallbacks controllerClientCallbacks;
static ControllerAdvertisedCallbacks controllerAdvertisedCallbacks;

static bool scanForController() {
  Serial.println("Scanning for BLE controller...");
  if (controllerAdvertised != nullptr) {
    delete controllerAdvertised;
    controllerAdvertised = nullptr;
  }

  BLEScan* scan = BLEDevice::getScan();
  scan->setAdvertisedDeviceCallbacks(&controllerAdvertisedCallbacks, true);
  scan->setInterval(100);
  scan->setWindow(80);
  scan->setActiveScan(true);

  scan->start(6, false);
  scan->clearResults();

  if (controllerAdvertised == nullptr) {
    Serial.println("BLE controller not found");
  }
  return controllerAdvertised != nullptr;
}

static bool connectToController() {
  ensureBleStackInitialized("ESP32-BLE");

  if (!scanForController()) {
    return false;
  }

  Serial.println("Connecting to BLE controller...");

  if (controllerClient == nullptr) {
    controllerClient = BLEDevice::createClient();
    controllerClient->setClientCallbacks(&controllerClientCallbacks);
  }

  if (!controllerClient->connect(controllerAdvertised)) {
    Serial.println("BLE controller connect failed");
    return false;
  }

  BLERemoteService* hidService = controllerClient->getService(HID_SERVICE_UUID);
  if (hidService == nullptr) {
    controllerClient->disconnect();
    Serial.println("BLE controller HID service not found");
    return false;
  }

  controllerReportChar = nullptr;
  auto* characteristics = hidService->getCharacteristics();
  for (auto it = characteristics->begin(); it != characteristics->end(); ++it) {
    BLERemoteCharacteristic* candidate = it->second;
    if (candidate->getUUID().equals(HID_REPORT_UUID) && candidate->canNotify()) {
      controllerReportChar = candidate;
      break;
    }
  }

  if (controllerReportChar == nullptr) {
    controllerClient->disconnect();
    Serial.println("BLE controller report characteristic not found");
    return false;
  }

  controllerReportChar->registerForNotify(controllerNotifyCallback);
  lastControllerPacketMs = millis();
  controllerConnected = true;
  return true;
}

void stopBLEController() {
  if (currentMode == MODE_BLE_CONTROLLER) {
    Serial.println("Stopping BLE controller mode");
  }
  if (controllerClient != nullptr) {
    if (controllerClient->isConnected()) {
      controllerClient->disconnect();
    }
  }

  if (controllerAdvertised != nullptr) {
    delete controllerAdvertised;
    controllerAdvertised = nullptr;
  }

  controllerReportChar = nullptr;
  controllerConnected = false;
  controllerConnecting = false;
  lastControllerPacketMs = 0;
}

void activateBLEController() {
  if (currentMode == MODE_BLE_CONTROLLER) return;

  Serial.println("Activating BLE controller mode");

  stopBLE();
  stopBLEController();

  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  udp.stop();
  udpResetControlEndpoint();

  ensureBleStackInitialized("ESP32-BLE");

  controllerModeStartMs = millis();
  lastControllerPacketMs = 0;
  lastConnectAttemptMs = 0;
  controllerConnected = false;
  controllerConnecting = false;

  currentMode = MODE_BLE_CONTROLLER;
}

void BLEControllerTransport() {
  if (currentMode != MODE_BLE_CONTROLLER) return;

  unsigned long now = millis();

  if (!controllerConnected) {
    if (now - controllerModeStartMs > BLE_CONTROLLER_CONNECT_TIMEOUT_MS) {
      Serial.println("BLE controller timeout -> main mode");
      stopBLEController();
      activateMainMode();
      return;
    }

    if (!controllerConnecting && now - lastConnectAttemptMs > CONTROLLER_RETRY_MS) {
      lastConnectAttemptMs = now;
      controllerConnecting = true;
      bool connected = connectToController();
      controllerConnecting = false;
      controllerConnected = connected;
    }
  } else if (now - lastControllerPacketMs > FAILSAFE_MS) {
    tx = ty = sx = sy = 0.0f;
  }
}
