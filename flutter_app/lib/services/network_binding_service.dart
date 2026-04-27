import 'dart:io';

import 'package:flutter/services.dart';

class NetworkBindingService {
  static const MethodChannel _channel =
      MethodChannel('flutter_rccontroller_app/network');

  static Future<void> bindToWifi({String? targetHost}) async {
    if (!Platform.isAndroid) return;

    try {
      final ok = await _channel.invokeMethod<bool>(
            'bindToWifi',
            {
              'targetHost': targetHost,
            },
          ) ??
          false;
      if (!ok) {
        throw const SocketException('Unable to bind process to Wi-Fi');
      }
    } on MissingPluginException {
      // Ignore in non-Android or test environments where channel is absent.
    } on PlatformException catch (e) {
      throw SocketException(
        e.message ?? 'Unable to bind process to Wi-Fi',
      );
    }
  }

  static Future<void> clearBinding() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<void>('clearBinding');
    } on MissingPluginException {
      // Ignore in non-Android or test environments where channel is absent.
    } on PlatformException {
      // Best effort cleanup; transport teardown should continue.
    }
  }

  static Future<bool> isWifiBound() async {
    if (!Platform.isAndroid) return true;

    try {
      return await _channel.invokeMethod<bool>('isWifiBound') ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}