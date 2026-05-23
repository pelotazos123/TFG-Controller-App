import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';

class FakeTransport implements ControlTransport {
  FakeTransport({this.connected = true, GpsTelemetry? gpsTelemetry})
      : _gpsTelemetry = gpsTelemetry;

  bool connected;
  GpsTelemetry? _gpsTelemetry;
  final List<Map<String, double>> sent = [];

  void setGps(GpsTelemetry? telemetry) => _gpsTelemetry = telemetry;

  @override
  bool get isConnected => connected;

  @override
  GpsTelemetry? get gpsTelemetry => _gpsTelemetry;

  @override
  Future<void> connect() async {
    connected = true;
  }

  @override
  void disconnect() {
    connected = false;
  }

  @override
  void send({
    required double tx,
    required double ty,
    required double sx,
    required double sy,
  }) {
    sent.add({'tx': tx, 'ty': ty, 'sx': sx, 'sy': sy});
  }

  @override
  Future<void> sendModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {}

  @override
  Future<void> sendMainModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {}
}

void main() {
  late ControlManager manager;

  setUp(() {
    manager = ControlManager.instance;
    manager.disconnect();
    manager.setDriveScale(1.0);
    manager.setReverseSteering(false);
    manager.setReverseThrottle(false);
  });

  test('setDriveScale range limits', () {
    manager.setDriveScale(2.5);
    expect(manager.driveScale, 1.0);

    manager.setDriveScale(0.0);
    expect(manager.driveScale, 0.2);

    manager.setDriveScale(0.6);
    expect(manager.driveScale, 0.6);
  });

  test('sendJoystick basic mapping without scaling or reverse', () {
    final transport = FakeTransport();
    manager.setTransport(transport);

    manager.sendJoystick(0.5, -0.7, 0.2, 0.0);

    expect(transport.sent, hasLength(1));
    final sent = transport.sent.single;
    expect(sent['tx'], closeTo(0.5, 0.0001));
    // ty is not used (protocol uses ty as 0.0)
    expect(sent['ty'], closeTo(0.0, 0.0001));
    expect(sent['sx'], closeTo(0.2, 0.0001));
    expect(sent['sy'], closeTo(-0.7, 0.0001));
  });

  test('sendJoystick applies scaling and reverse flags', () {
    final transport = FakeTransport();
    manager.setTransport(transport);
    manager.setDriveScale(0.5);
    manager.setReverseSteering(true);
    manager.setReverseThrottle(true);

    manager.sendJoystick(0.8, -0.4, 0.6, 0.0);

    expect(transport.sent, hasLength(1));
    final sent = transport.sent.single;
    expect(sent['tx'], closeTo(-0.4, 0.0001));
    expect(sent['ty'], closeTo(0.0, 0.0001));
    expect(sent['sx'], closeTo(0.3, 0.0001));
    expect(sent['sy'], closeTo(0.2, 0.0001));
  });

  test('motion commands override joystick input', () {
    final transport = FakeTransport();
    manager.setTransport(transport);

    manager.sendJoystick(0.2, 0.1, 0.3, 0.0);
    transport.sent.clear();

    manager.setMotionCommand(MotionCommand.forwardLeft, power: 0.5);

    expect(transport.sent, hasLength(1));
    final sent = transport.sent.single;
    expect(sent['tx'], closeTo(-0.5, 0.0001));
    expect(sent['sx'], closeTo(0.0, 0.0001));
    expect(sent['sy'], closeTo(0.5, 0.0001));
  });

  test('clearing motion command stops stale movement', () {
    final transport = FakeTransport();
    manager.setTransport(transport);

    manager.sendJoystick(0.7, 0.0, 0.4, 0.0);
    transport.sent.clear();

    manager.setMotionCommand(MotionCommand.forwardLeft, power: 0.5);
    transport.sent.clear();

    manager.setMotionCommand(null);

    expect(transport.sent, hasLength(1));
    final sent = transport.sent.single;
    expect(sent['tx'], closeTo(0.0, 0.0001));
    expect(sent['ty'], closeTo(0.0, 0.0001));
    expect(sent['sx'], closeTo(0.0, 0.0001));
    expect(sent['sy'], closeTo(0.0, 0.0001));
  });

  test('gps telemetry syncs from transport', () {
    final transport = FakeTransport();
    manager.setTransport(transport);

    final gpsOne = GpsTelemetry(
      valid: true,
      latitude: 43.0,
      longitude: -5.0,
      altitude: 120.0,
      speedKmph: 5.0,
      satellites: 6,
      ageMs: 100,
      receivedAt: DateTime(2024, 1, 1),
    );
    transport.setGps(gpsOne);

    manager.sendJoystick(0.0, 0.0, 0.0, 0.0);
    expect(manager.gpsTelemetry, gpsOne);

    final gpsTwo = GpsTelemetry(
      valid: false,
      latitude: 42.5,
      longitude: -5.5,
      altitude: 80.0,
      speedKmph: 0.0,
      satellites: 3,
      ageMs: 400,
      receivedAt: DateTime(2024, 1, 2),
    );
    transport.setGps(gpsTwo);

    manager.sendJoystick(0.0, 0.0, 0.0, 0.0);
    expect(manager.gpsTelemetry, gpsTwo);
  });

  test('connect starts transport', () async {
    final transport = FakeTransport(connected: false);
    manager.setTransport(transport);
    await manager.connect();

    expect(transport.isConnected, isTrue);
    expect(manager.isConnected, isTrue);
  });

  test('disconnect stops transport and clears state', () {
    final transport = FakeTransport(connected: true);
    manager.setTransport(transport);

    manager.disconnect();

    expect(transport.isConnected, isFalse);
    expect(manager.isConnected, isFalse);
    expect(manager.gpsTelemetry, isNull);
  });
}