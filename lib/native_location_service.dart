import 'dart:io';

import 'package:flutter/services.dart';

class NativeLocationService {
  static const MethodChannel _channel = MethodChannel(
    'com.locationtracking.locationtracking/driver_location',
  );

  Future<void> start(String driverId) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<bool>('start', {'driverId': driverId});
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<bool>('stop');
  }

  Future<Map<String, dynamic>> status() async {
    if (!Platform.isAndroid) return const {'isRunning': false};

    final result = await _channel.invokeMapMethod<String, dynamic>('status');
    return result ?? const {'isRunning': false};
  }
}
