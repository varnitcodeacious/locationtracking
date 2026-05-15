import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:firebase_database/firebase_database.dart';

import '../location_app_state_resolver.dart';

/// Merges app lifecycle into `live_drivers` without touching lat/lng.
Future<void> syncAppStateToFirebase(String driverId, String appStateLabel) async {
  final db = FirebaseDatabase.instance;
  await db.ref('live_drivers/$driverId').update({
    'app_state': appStateLabel,
  });
}

/// Pushes [data] to Realtime Database for [driverId] (live node + history).
Future<void> syncLocationUpdateToFirebase(
  BackgroundLocationUpdateData data,
  String driverId,
) async {
  final db = FirebaseDatabase.instance;
  final heading = data.course >= 0 ? data.course : 0.0;
  final speed = data.speed >= 0 ? data.speed : 0.0;
  final appState = await resolveAppStateForLocationSample();

  await db.ref('live_drivers/$driverId').set({
    'lat': data.lat,
    'lng': data.lon,
    'heading': heading,
    'speed': speed,
    'last_updated': ServerValue.timestamp,
    'is_online': true,
    'app_state': appState,
  });

  await db.ref('driver_history/$driverId').push().set({
    'lat': data.lat,
    'lng': data.lon,
    'speed': speed,
    'app_state': appState,
    'timestamp': ServerValue.timestamp,
  });
}
