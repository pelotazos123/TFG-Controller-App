import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/transport/transport_message.dart';

class BleTransport implements ControlTransport {
  static const String deviceName = 'ESP32-BLE';
  static final Guid serviceUuid = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  static final Guid rxUuid = Guid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E');
  static final Guid txUuid = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  bool _connected = false;
  final StreamController<TransportEvent> _terminalEvents =
      StreamController<TransportEvent>.broadcast();

  bool get _canSend => _connected && _rxChar != null;

  @override
  bool get isConnected => _connected;

  @override
  Stream<TransportEvent> get terminalEvents => _terminalEvents.stream;

  @override
  Future<void> connect() async {
    if (_connected) return;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw StateError('Bluetooth is off');
    }

    final targetCompleter = Completer<ScanResult>();
    final scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (targetCompleter.isCompleted) return;
      for (final result in results) {
        final name = result.device.platformName;
        final advName = result.advertisementData.advName;
        if (name == deviceName || advName == deviceName) {
          targetCompleter.complete(result);
          break;
        }
      }
    });

    ScanResult target;
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      target = await targetCompleter.future
          .timeout(const Duration(seconds: 10));
    } finally {
      await FlutterBluePlus.stopScan();
      await scanSub.cancel();
    }

    _device = target.device;
    try {
      // Clear any stale Android connection state before reconnecting.
      await _device!.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await _device!.connect(
        timeout: const Duration(seconds: 8),
        autoConnect: false,
      );

      await _device!.connectionState
          .firstWhere((s) => s == BluetoothConnectionState.connected)
          .timeout(const Duration(seconds: 8));

      _connectionSub?.cancel();
      _connectionSub = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connected = false;
        }
      });

      try {
        await _device!.requestConnectionPriority(
          connectionPriorityRequest: ConnectionPriority.high,
        );
      } catch (_) {
        // Ignore priority failures on unsupported platforms.
      }
    } catch (error) {
      debugPrint('BLE connect failed: $error');
      disconnect();
      rethrow;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final services = await _device!.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == serviceUuid,
      orElse: () => throw StateError('BLE service not found'),
    );

    _rxChar = service.characteristics.firstWhere(
      (c) => c.uuid == rxUuid,
      orElse: () => throw StateError('BLE RX characteristic not found'),
    );
    _txChar = service.characteristics.firstWhere(
      (c) => c.uuid == txUuid,
      orElse: () => throw StateError('BLE TX characteristic not found'),
    );

    try {
      // Encrypted write triggers bonding prompt on Android when required.
      final ping = utf8.encode('{"type":"ping"}');
      await _rxChar!
          .write(ping, withoutResponse: false)
          .timeout(const Duration(seconds: 8));

      await _txChar!
          .setNotifyValue(true)
          .timeout(const Duration(seconds: 6));
      await Future.delayed(const Duration(milliseconds: 200));
      _notifySub = _txChar!.lastValueStream.listen(_handleNotification);
      _connected = true;
    } catch (error) {
      debugPrint('BLE init failed: $error');
      disconnect();
      rethrow;
    }
  }

  void _handleNotification(List<int> data) {
    if (data.isEmpty) return;

    if (data.length > maxInboundPacketBytes) return;

    final raw = _decodePacket(data);
    if (raw == null || !_looksLikeJson(raw)) return;
    try {
      final decoded = jsonDecode(raw);
      final pkt = parseIncomingPacket(decoded);
      if (pkt != null) {
        if (pkt.type == 'log' || pkt.type == 'terminal' || pkt.type == 'hello_ack') {
          _terminalEvents.add(
            parseTransportEvent(decoded) ??
                TransportEvent(
                  type: pkt.type,
                  data: Map<String, dynamic>.from(decoded),
                  receivedAt: DateTime.now(),
                ),
          );
        }
      }
    } catch (error) {
      debugPrint('BLE packet parse error: $error');
    }
  }

  @override
  void disconnect() {
    _notifySub?.cancel();
    _notifySub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _connected = false;
    final device = _device;
    _device = null;
    _rxChar = null;
    _txChar = null;

    if (device != null) {
      unawaited(device.disconnect().catchError((_) {}));
    }
  }

  @override
  void send({
    required double tx,
    required double ty,
    required double sx,
    required double sy,
    required double driveScale,
  }) {
    if (!_canSend) return;
    final payload = buildControlPayload(tx, ty, sx, sy, driveScale);
    _writePayload(payload, withoutResponse: true, errorContext: 'send');
  }

  @override
  Future<void> sendTerminalCommand(String command) async {
    if (!_canSend) return;

    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    final payload = jsonEncode({
      'type': 'terminal',
      'command': trimmed,
    });

    await _writePayloadAwaited(
      payload,
      withoutResponse: false,
      errorContext: 'terminal command',
    );
  }

  @override
  Future<void> sendModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {
    if (!_canSend) return;

    final payload = jsonEncode({
      'type': 'set_mode',
      'mode': controllerModeToPayload(mode),
      'ssid': ?ssid,
      'pass': ?password,
    });

    await _writePayloadAwaited(
      payload,
      withoutResponse: false,
      errorContext: 'mode command',
    );
  }

  @override
  Future<void> sendMainModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {
    if (!_canSend) return;

    final payload = jsonEncode({
      'type': 'set_main_mode',
      'mode': controllerModeToPayload(mode),
      'ssid': ?ssid,
      'pass': ?password,
    });

    await _writePayloadAwaited(
      payload,
      withoutResponse: false,
      errorContext: 'main mode command',
    );
  }

  void _writePayload(
    String payload, {
    required bool withoutResponse,
    required String errorContext,
  }) {
    if (!_canSend) return;
    unawaited(
      _rxChar!
          .write(utf8.encode(payload), withoutResponse: withoutResponse)
          .catchError((error) => debugPrint('BLE $errorContext failed: $error')),
    );
  }

  Future<void> _writePayloadAwaited(
    String payload, {
    required bool withoutResponse,
    required String errorContext,
  }) async {
    if (!_canSend) return;
    try {
      await _rxChar!.write(utf8.encode(payload), withoutResponse: withoutResponse);
    } catch (error) {
      debugPrint('BLE $errorContext failed: $error');
    }
  }

  String? _decodePacket(List<int> data) {
    try {
      return utf8.decode(data);
    } on FormatException {
      return null;
    }
  }

  bool _looksLikeJson(String raw) {
    final trimmed = raw.trimLeft();
    return trimmed.isNotEmpty && trimmed.codeUnitAt(0) == 0x7b;
  }
}
