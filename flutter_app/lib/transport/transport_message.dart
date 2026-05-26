import 'dart:convert';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';

const int maxInboundPacketBytes = 1024;

String buildControlPayload(double tx, double ty, double sx, double sy) {
  return jsonEncode({
    'type': 'control',
    'tx': tx,
    'ty': ty,
    'sx': sx,
    'sy': sy,
  });
}

GpsTelemetry parseGpsTelemetry(Map data) {
  return GpsTelemetry(
    valid: data['valid'] == true,
    latitude: _toDouble(data['lat']),
    longitude: _toDouble(data['lon']),
    altitude: _toDouble(data['alt']),
    speedKmph: _toDouble(data['speed']),
    satellites: _toInt(data['sat']),
    ageMs: _toInt(data['age']),
    receivedAt: DateTime.now(),
  );
}

class IncomingPacket {
  final String type;
  final Map<String, dynamic> data;

  IncomingPacket({required this.type, required this.data});
}

/// Attempts to parse a decoded JSON value into an [IncomingPacket].
/// Returns `null` if the value is not a Map or doesn't contain a string `type`.
IncomingPacket? parseIncomingPacket(dynamic decoded) {
  if (decoded is Map) {
    final t = decoded['type'];
    if (t is String) {
      try {
        final map = Map<String, dynamic>.from(decoded);
        return IncomingPacket(type: t, data: map);
      } catch (_) {
        // Fall through to return null on cast failures.
      }
    }
  }
  return null;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
