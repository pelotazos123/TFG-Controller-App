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

class GpsTelemetry {
  final bool valid;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedKmph;
  final int satellites;
  final int ageMs;
  final DateTime receivedAt;

  const GpsTelemetry({
    required this.valid,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speedKmph,
    required this.satellites,
    required this.ageMs,
    required this.receivedAt,
  });
}
