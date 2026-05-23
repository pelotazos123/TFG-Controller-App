#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"
#include "BLESecurity.h"
#include "params.h"

// ==================== BLE ===================
BLECharacteristic *pTxCharacteristic;
BLECharacteristic *pRxCharacteristic;
bool deviceConnected = false;
static bool bleInitialized = false;
static BLEServer *bleServer = nullptr;
static BLEAdvertising *bleAdvertising = nullptr;

static unsigned long lastBlePacketMs = 0;
static unsigned long lastBleActivityMs = 0;
static unsigned long lastBleDisconnectMs = 0;
static unsigned long bleModeStartMs = 0;
static unsigned long lastBleGpsMs = 0;
static const unsigned long BLE_GPS_SEND_MS = 1000;
static const unsigned long BLE_WIFI_RETURN_MS = 1200;

#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    deviceConnected = true;
    noteModeActivity(MODE_BLE);
  }
  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    lastBleDisconnectMs = millis();
    delay(100);
    pServer->getAdvertising()->start();
  }
};

static bool handleBleFallback() {
  if (currentMode != MODE_BLE) return false;
  if (deviceConnected) return false;

  unsigned long now = millis();
  unsigned long lastActivity = lastBleActivityMs;
  if (lastBleDisconnectMs > lastActivity) {
    lastActivity = lastBleDisconnectMs;
  }
  if (lastActivity == 0) {
    lastActivity = bleModeStartMs;
  }
  if (lastActivity == 0) return false;

  if (mainMode == MODE_WIFI_AP) {
    if (now - lastActivity > BLE_WIFI_RETURN_MS) {
      activateFallbackMode();
      return true;
    }
  }

  if (MODE_FALLBACK_MS == 0) return false;
  if (mainMode == MODE_BLE) return false;

  if (now - lastActivity > MODE_FALLBACK_MS) {
    activateFallbackMode();
    return true;
  }
  return false;
}

static void applyBleFailsafe() {
  if (millis() - lastBlePacketMs > FAILSAFE_MS) {
    tx = ty = sx = sy = 0.0f;
  }
}

static void handleBleControlPacket(JsonDocument& doc) {
  tx = doc["tx"] | 0.0;
  ty = doc["ty"] | 0.0;
  sx = doc["sx"] | 0.0;
  sy = doc["sy"] | 0.0;
  lastBlePacketMs = millis();
}

static void processBlePayload(const uint8_t* data, size_t len) {
  if (data == nullptr || len == 0) return;

  StaticJsonDocument<160> doc;
  DeserializationError err = deserializeJson(doc, data, len);
  if (err != DeserializationError::Ok) {
    return;
  }

  lastBleActivityMs = millis();

  const char* msgType = doc["type"];
  if (msgType && String(msgType) == "set_mode") {
    const char* modeValue = doc["mode"];
    const char* ssid = doc["ssid"];
    const char* pass = doc["pass"];
    requestModeChange(modeValue, ssid, pass);
    return;
  }

  if (msgType && String(msgType) == "set_main_mode") {
    const char* modeValue = doc["mode"];
    const char* ssid = doc["ssid"];
    const char* pass = doc["pass"];
    requestMainModeChange(modeValue, ssid, pass);
    return;
  }

  if (msgType == nullptr || String(msgType) == "control") {
    handleBleControlPacket(doc);
  }
}

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    const uint8_t* data = pCharacteristic->getData();
    size_t len = pCharacteristic->getLength();
    processBlePayload(data, len);
  }
};

void setupBLE() {
  ensureBleStackInitialized("ESP32-BLE");
  if (bleInitialized) {
    if (bleAdvertising != nullptr) {
      bleAdvertising->start();
    } else {
      bleAdvertising = BLEDevice::getAdvertising();
      bleAdvertising->start();
    }
    return;
  }

  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new MyServerCallbacks());

  BLESecurity *pSecurity = new BLESecurity();
  pSecurity->setAuthenticationMode(ESP_LE_AUTH_BOND);
  pSecurity->setCapability(ESP_IO_CAP_NONE);
  pSecurity->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
  pSecurity->setRespEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);

  BLEService *pService = bleServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pTxCharacteristic->setAccessPermissions(ESP_GATT_PERM_READ_ENCRYPTED);
  pTxCharacteristic->addDescriptor(new BLE2902());

  pRxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  
  // Require encrypted writes so the OS forces bonding.
  pRxCharacteristic->setAccessPermissions(ESP_GATT_PERM_WRITE_ENCRYPTED);
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  bleAdvertising = BLEDevice::getAdvertising();
  bleAdvertising->addServiceUUID(SERVICE_UUID);
  bleAdvertising->setScanResponse(true);
  bleAdvertising->setMinPreferred(0x06);

  pService->start();
  bleServer->getAdvertising()->start();
  bleInitialized = true;
}

void stopBLE() {
  if (!bleInitialized) return;
  if (bleAdvertising != nullptr) {
    bleAdvertising->stop();
  }
  deviceConnected = false;
}

static void sendBleGpsTelemetryIfDue() {
  if (!deviceConnected || pTxCharacteristic == nullptr) return;

  unsigned long now = millis();
  if (now - lastBleGpsMs < BLE_GPS_SEND_MS) return;
  lastBleGpsMs = now;

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
  pTxCharacteristic->setValue((uint8_t*)out, outLen);
  if (deviceConnected) {
    pTxCharacteristic->notify();
  }
}

void activateBLE() {
  if (currentMode == MODE_BLE) return;

  stopBLEController();
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  udp.stop();
  udpResetControlEndpoint();

  setupBLE();

  bleModeStartMs = millis();
  lastBlePacketMs = 0;
  lastBleActivityMs = 0;
  lastBleDisconnectMs = 0;

  currentMode = MODE_BLE;
}

void BLEtransport() {
  applyBleFailsafe();
  sendBleGpsTelemetryIfDue();
  if (handleBleFallback()) return;
}