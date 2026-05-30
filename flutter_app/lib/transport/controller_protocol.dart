enum ControllerMode {
  wifiAp,
  ble,
}

String controllerModeToPayload(ControllerMode mode) {
  return switch (mode) {
    ControllerMode.wifiAp => 'wifi_ap',
    ControllerMode.ble => 'ble',
  };
}

