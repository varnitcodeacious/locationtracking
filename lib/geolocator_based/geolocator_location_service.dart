import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../location_debug/location_logger.dart';

class GeolocatorLocationService {
  GeolocatorLocationService({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;
  StreamSubscription<Position>? _positionSubscription;
  String? _driverId;

  bool get isRunning => _positionSubscription != null;

  Future<void> start(String driverId) async {
    await ensureLocationPermissionForTracking();

    if (_driverId == driverId && isRunning) return;
    await stop();

    _driverId = driverId;
    await _database.ref('live_drivers/$driverId').update({
      'is_online': true,
      'last_updated': ServerValue.timestamp,
    });

    final currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 45),
    );
    await _savePosition(currentPosition, driverId);

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (position) => _handlePosition(position, driverId),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Geolocator position stream error: $error');
      },
    );
  }

  Future<void> stop() async {
    final driverId = _driverId;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _driverId = null;

    if (driverId != null) {
      await _database.ref('live_drivers/$driverId').update({
        'is_online': false,
        'last_updated': ServerValue.timestamp,
      });
    }
  }

  Future<Map<String, dynamic>> status() async {
    return {'isRunning': isRunning};
  }

  /// Ensures device GPS is on and location is [LocationPermission.always]
  /// (Allow all the time / Always) so background tracking is allowed.
  Future<void> ensureLocationPermissionForTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it in app settings.',
      );
    }

    // "Allow all the time" (Android) / "Always" (iOS) for background tracking.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse) {
      final opened = await Geolocator.openAppSettings();
      final hint = opened
          ? ' In Settings, set location to Allow all the time (Android) or Always (iOS), then try again.'
          : ' Open app settings and set location to Allow all the time / Always, then try again.';
      throw Exception(
        'All-the-time location access is required for background tracking.$hint',
      );
    }

    if (permission == LocationPermission.unableToDetermine) {
      throw Exception('Location permission could not be determined.');
    }

    if (permission != LocationPermission.always) {
      throw Exception('Full location access is required to start tracking.');
    }
  }

  Future<void> _savePosition(Position position, String driverId) async {
    unawaited(LocationLogger.instance.logPosition(position));

    final locationData = {
      'lat': position.latitude,
      'lng': position.longitude,
      'heading': position.heading,
      'speed': position.speed,
      'accuracy': position.accuracy,
      'last_updated': ServerValue.timestamp,
      'is_online': true,
    };

    await _database.ref('live_drivers/$driverId').set(locationData);
    await _database.ref('driver_history/$driverId').push().set({
      'lat': position.latitude,
      'lng': position.longitude,
      'heading': position.heading,
      'speed': position.speed,
      'accuracy': position.accuracy,
      'timestamp': ServerValue.timestamp,
    });
  }

  void _handlePosition(Position position, String driverId) {
    _savePosition(position, driverId).catchError((Object error) {
      debugPrint('Failed to save driver location: $error');
    });
  }

  LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Driver location active',
          notificationText: 'Sharing your location while you are on duty.',
          notificationChannelName: 'Driver location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }
}
