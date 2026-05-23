import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';
import 'package:flutter_rccontroller_app/transport/transport_codec.dart';

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
  GpsTelemetry? _gpsTelemetry;

  @override
  bool get isConnected => _connected;

  @override
  GpsTelemetry? get gpsTelemetry => _gpsTelemetry;

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
    } catch (_) {
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
    } catch (_) {
      disconnect();
      rethrow;
    }
  }

  void _handleNotification(List<int> data) {
    if (data.isEmpty) return;

    final raw = utf8.decode(data, allowMalformed: true);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['type'] == 'gps') {
        _gpsTelemetry = parseGpsTelemetry(decoded);
      }
    } catch (_) {
      // Ignore malformed packets.
    }
  }

  @override
  void disconnect() {
    _notifySub?.cancel();
    _notifySub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _gpsTelemetry = null;
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
  }) {
    if (!_connected || _rxChar == null) return;

    final payload = buildSendPayload(tx, ty, sx, sy);
    unawaited(_rxChar!.write(utf8.encode(payload), withoutResponse: true).catchError((_) {}));
  }

  @override
  Future<void> sendModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {
    if (!_connected || _rxChar == null) return;

    final payload = jsonEncode({
      'type': 'set_mode',
      'mode': controllerModeToPayload(mode),
      if (ssid != null) 'ssid': ssid,
      if (password != null) 'pass': password,
    });

    try {
      await _rxChar!.write(utf8.encode(payload), withoutResponse: false);
    } catch (_) {
      // Ignore BLE write failures during disconnects.
    }
  }

  @override
  Future<void> sendMainModeCommand(
    ControllerMode mode, {
    String? ssid,
    String? password,
  }) async {
    if (!_connected || _rxChar == null) return;

    final payload = jsonEncode({
      'type': 'set_main_mode',
      'mode': controllerModeToPayload(mode),
      if (ssid != null) 'ssid': ssid,
      if (password != null) 'pass': password,
    });

    try {
      await _rxChar!.write(utf8.encode(payload), withoutResponse: false);
    } catch (_) {
      // Ignore BLE write failures during disconnects.
    }
  }

  static String buildSendPayload(double tx, double ty, double sx, double sy) {
    return buildControlPayload(tx, ty, sx, sy);
  }
}
