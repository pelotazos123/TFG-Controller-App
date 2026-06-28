import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/transport/transport_message.dart';

class FakeTransport implements ControlTransport {
  FakeTransport({this.connected = true});

  bool connected;
  final List<Map<String, double>> sent = [];

  @override
  Stream<TransportEvent> get terminalEvents => const Stream<TransportEvent>.empty();

  @override
  bool get isConnected => connected;

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
    required double driveScale,
  }) {
    sent.add({'tx': tx, 'ty': ty, 'sx': sx, 'sy': sy, 'ds': driveScale});
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

  @override
  Future<void> sendTerminalCommand(String command) async {}
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
    expect(manager.driveScale, 0.5);

    manager.setDriveScale(0.6);
    expect(manager.driveScale, 0.6);
  });

  test('sendJoystick basic mapping without scaling or reverse', () {
    final transport = FakeTransport();
    manager.setTransport(transport);

    manager.sendJoystick(0.5, -0.7, 0.2);

    expect(transport.sent, hasLength(1));
    final sent = transport.sent.single;
    expect(sent['tx'], closeTo(0.5, 0.0001));
    // ty is not used (protocol uses ty as 0.0)
    expect(sent['ty'], closeTo(0.0, 0.0001));
    expect(sent['sx'], closeTo(0.2, 0.0001));
    expect(sent['sy'], closeTo(-0.7, 0.0001));
  });

  test('sendJoystick applies reverse flags and passes driveScale to transport', () {
    final transport = FakeTransport();
    manager.setTransport(transport);
    manager.setDriveScale(0.5);
    manager.setReverseSteering(true);
    manager.setReverseThrottle(true);

    manager.sendJoystick(0.8, -0.4, 0.6);

    expect(transport.sent, hasLength(1));
    final sent = transport.sent.single;
    // reverseThrottle inverts tx and sy; reverseSteering inverts sx
    // driveScale is forwarded to firmware, not applied in app
    expect(sent['tx'], closeTo(-0.8, 0.0001));
    expect(sent['ty'], closeTo(0.0, 0.0001));
    expect(sent['sx'], closeTo(-0.6, 0.0001));
    expect(sent['sy'], closeTo(0.4, 0.0001));
    expect(sent['ds'], closeTo(0.5, 0.0001));
  });

  test('motion commands override joystick input', () {
    final transport = FakeTransport();
    manager.setTransport(transport);

    manager.sendJoystick(0.2, 0.1, 0.3);
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

    manager.sendJoystick(0.7, 0.0, 0.4);
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
  });
}