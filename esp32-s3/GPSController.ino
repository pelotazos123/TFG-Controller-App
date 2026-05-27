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
static unsigned long lastGpsSummaryMs = 0;

void setupGPS() {
	gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
	logTrace("INFO", "GPS", "started RX=%d TX=%d baud=%lu", GPS_RX_PIN, GPS_TX_PIN, (unsigned long)GPS_BAUD);
	if (LOG_GPS_TRACES) {
		logTrace("INFO", "GPS", "waiting for NMEA data");
	}
}

void gpsUpdate() {
	uint32_t bytesRead = 0;
	while (gpsSerial.available() > 0) {
		gps.encode((char)gpsSerial.read());
		bytesRead++;
	}

	if (LOG_GPS_TRACES && bytesRead > 0 && millis() - lastGpsTraceMs >= 1000) {
		logTrace("DEBUG", "GPS", "parsed %lu bytes of NMEA", (unsigned long)bytesRead);
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
			if (millis() - lastGpsSummaryMs >= 2000) {
				logTrace(
					"INFO",
					"GPS",
					"valid=1 lat=%.6f lon=%.6f alt=%.1fm speed=%.1fkm/h sats=%lu age=%lums",
					lastLat,
					lastLon,
					lastAltM,
					lastSpeedKmph,
					(unsigned long)lastSatellites,
					(unsigned long)(millis() - lastFixMs)
				);
				lastGpsSummaryMs = millis();
			}
		}
	}

	if (LOG_GPS_TRACES && hasFix != lastTraceFixState) {
		lastTraceFixState = hasFix;
		if (hasFix) {
			logTrace("INFO", "GPS", "fix acquired");
		} else {
			logTrace("WARN", "GPS", "fix lost");
		}
	}

	// If we stop receiving valid fixes for a while, mark it invalid.
	if (hasFix && millis() - lastFixMs > 5000) {
		hasFix = false;
		if (LOG_GPS_TRACES) {
			logTrace("WARN", "GPS", "timeout: no valid fix for %lu ms", (unsigned long)(millis() - lastFixMs));
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
