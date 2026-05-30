import 'dart:convert';

const int maxInboundPacketBytes = 1024;

class TransportEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  TransportEvent({
    required this.type,
    required this.data,
    required this.receivedAt,
  });

  String toDisplayLine() {
    final prefix = '[${receivedAt.toIso8601String().substring(11, 19)}]';

    switch (type) {
        case 'log':
        final level = (data['level'] as String?)?.toUpperCase() ?? 'INFO';
        final tag = (data['tag'] as String?) ?? 'TERM';
        final message = (data['message'] as String?) ?? '';
        return '$prefix $level $tag: $message';
      case 'hello_ack':
        return '$prefix INFO UDP: hello_ack server_ms=${_formatInt(data['server_ms'])}';
      case 'terminal':
        final command = (data['command'] as String?) ?? '';
        final message = (data['message'] as String?) ?? '';
        return '$prefix TERM: $command${message.isEmpty ? '' : ' -> $message'}';
      default:
        return '$prefix ${type.toUpperCase()}: ${jsonEncode(data)}';
    }
  }
}

TransportEvent? parseTransportEvent(dynamic decoded) {
  if (decoded is! Map) return null;

  final typeValue = decoded['type'];
  if (typeValue is! String) return null;

  try {
    return TransportEvent(
      type: typeValue,
      data: Map<String, dynamic>.from(decoded),
      receivedAt: DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}

String buildControlPayload(double tx, double ty, double sx, double sy) {
  return jsonEncode({
    'type': 'control',
    'tx': tx,
    'ty': ty,
    'sx': sx,
    'sy': sy,
  });
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

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _formatInt(Object? value) {
  return _toInt(value).toString();
}
