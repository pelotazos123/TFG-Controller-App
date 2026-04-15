#include "params.h"
#include <TinyGPSPlus.h>

static TinyGPSPlus gps;
static HardwareSerial gpsSerial(1);

static double lastLat = 0.0;
static double lastLon = 0.0;
static double lastAltM = 0.0;
static double lastSpeedKmph = 0.0;
static uint32_t lastSatellites = 0;

static bool hasFix = false;
static unsigned long lastFixMs = 0;

void setupGPS() {
	gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
	Serial.printf("GPS iniciado (RX=%d, TX=%d, %lu bps)\n", GPS_RX_PIN, GPS_TX_PIN, GPS_BAUD);
}

void gpsUpdate() {
	while (gpsSerial.available() > 0) {
		gps.encode((char)gpsSerial.read());
	}

	if (gps.location.isUpdated()) {
		if (gps.location.isValid()) {
			lastLat = gps.location.lat();
			lastLon = gps.location.lng();
			hasFix = true;
			lastFixMs = millis();
		}

		if (gps.altitude.isValid()) {
			lastAltM = gps.altitude.meters();
		}

		if (gps.speed.isValid()) {
			lastSpeedKmph = gps.speed.kmph();
		}

		if (gps.satellites.isValid()) {
			lastSatellites = gps.satellites.value();
		}
	}

	// If we stop receiving valid fixes for a while, mark it invalid.
	if (hasFix && millis() - lastFixMs > 5000) {
		hasFix = false;
	}
}

bool gpsHasValidFix() {
	return hasFix;
}

double gpsLatitude() {
	return lastLat;
}

double gpsLongitude() {
	return lastLon;
}

double gpsAltitudeM() {
	return lastAltM;
}

double gpsSpeedKmph() {
	return lastSpeedKmph;
}

uint32_t gpsSatellites() {
	return lastSatellites;
}

uint32_t gpsFixAgeMs() {
	if (!hasFix) return UINT32_MAX;
	return (uint32_t)(millis() - lastFixMs);
}
