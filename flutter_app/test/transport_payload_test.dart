import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rccontroller_app/transport/transport_message.dart';

void main() {
  test('shared control payload builder is valid JSON with expected keys', () {
    final jsonStr = buildControlPayload(0.1, 0.2, 0.3, 0.4);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    expect(decoded['tx'], 0.1);
    expect(decoded['ty'], 0.2);
    expect(decoded['sx'], 0.3);
    expect(decoded['sy'], 0.4);
    expect(buildControlPayload(0.1, 0.2, 0.3, 0.4), jsonStr);
  });
}
