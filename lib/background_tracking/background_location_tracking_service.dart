import 'dart:io' show Platform;

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tracking_prefs_keys.dart';

/// Foreground API for starting/stopping [BackgroundLocationTrackerManager].
class BackgroundLocationTrackingService {
  Future<Map<String, Object?>> status() async {
    final isRunning = await BackgroundLocationTrackerManager.isTracking();
    return {'isRunning': isRunning};
  }

  Future<void> start(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTrackingDriverIdPrefsKey, driverId);
    await BackgroundLocationTrackerManager.startTracking(
      config: AndroidConfig(
        channelName: 'Location tracking',
        notificationBody: 'Sharing your live location.',
        trackingInterval: const Duration(seconds: 10),
      ),
    );
  }

  Future<void> stop() async {
    await BackgroundLocationTrackerManager.stopTracking();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTrackingDriverIdPrefsKey);
  }

  /// Requests location (when-in-use then always) needed for background tracking.
  Future<void> ensureLocationPermissionForTracking() async {
    if (kIsWeb) {
      throw UnsupportedError('Background tracking is not supported on web.');
    }

    final serviceStatus = await Permission.location.serviceStatus;
    if (serviceStatus == ServiceStatus.disabled) {
      throw Exception(
        'Device location (GPS) is turned off. Enable it in system settings.',
      );
    }

    // iOS: use locationWhenInUse; Android maps Permission.location the same way.
    final whenInUsePermission = Platform.isIOS
        ? Permission.locationWhenInUse
        : Permission.location;
    var whenInUse = await whenInUsePermission.status;
    if (whenInUse.isDenied) {
      whenInUse = await whenInUsePermission.request();
    }
    if (whenInUse.isPermanentlyDenied) {
      await openAppSettings();
      throw Exception(
        'Location permission is blocked. Allow location in app settings.',
      );
    }
    if (!whenInUse.isGranted) {
      throw Exception('Location while-in-use permission was not granted.');
    }

    if (Platform.isIOS || Platform.isAndroid) {
      var always = await Permission.locationAlways.status;
      if (always.isDenied) {
        always = await Permission.locationAlways.request();
      }
      if (always.isPermanentlyDenied) {
        await openAppSettings();
        throw Exception(
          'Background location is blocked. Allow "Always" location in app settings.',
        );
      }
      if (!always.isGranted) {
        throw Exception(
          'Always / all-the-time location permission is required for duty tracking.',
        );
      }
    }
  }
}
