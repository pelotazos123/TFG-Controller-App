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
static unsigned long lastGpsTraceMs = 0;
static bool lastTraceFixState = false;

void setupGPS() {
	gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
	Serial.printf("GPS iniciado (RX=%d, TX=%d, %lu bps)\n", GPS_RX_PIN, GPS_TX_PIN, GPS_BAUD);
	if (LOG_GPS_TRACES) {
		Serial.println("GPS trace active: waiting for NMEA data...");
	}
}

void gpsUpdate() {
	uint32_t bytesRead = 0;
	while (gpsSerial.available() > 0) {
		gps.encode((char)gpsSerial.read());
		bytesRead++;
	}

	if (LOG_GPS_TRACES && bytesRead > 0 && millis() - lastGpsTraceMs >= 1000) {
		Serial.printf("GPS RX: %lu bytes processed\n", (unsigned long)bytesRead);
		lastGpsTraceMs = millis();
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

		if (LOG_GPS_TRACES && gps.location.isValid()) {
			Serial.printf(
				"GPS fix: lat=%.6f lon=%.6f alt=%.1f m speed=%.1f km/h sat=%lu age=%lu ms\n",
				lastLat,
				lastLon,
				lastAltM,
				lastSpeedKmph,
				(unsigned long)lastSatellites,
				(unsigned long)(millis() - lastFixMs)
			);
		}
	}

	if (LOG_GPS_TRACES && hasFix != lastTraceFixState) {
		lastTraceFixState = hasFix;
		if (hasFix) {
			Serial.println("GPS fix acquired");
		} else {
			Serial.println("GPS fix lost");
		}
	}

	// If we stop receiving valid fixes for a while, mark it invalid.
	if (hasFix && millis() - lastFixMs > 5000) {
		hasFix = false;
		if (LOG_GPS_TRACES) {
			Serial.printf("GPS timeout: no valid fix for %lu ms\n", (unsigned long)(millis() - lastFixMs));
		}
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
