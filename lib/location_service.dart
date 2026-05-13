import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

Future<void> handleNewPosition(Position position, String driverId) async {
  final db = FirebaseDatabase.instance;

  // Update LIVE position in Realtime Database ONLY
  await db.ref('live_drivers/$driverId').set({
    'lat': position.latitude,
    'lng': position.longitude,
    'heading': position.heading,
    'speed': position.speed,
    'last_updated': ServerValue.timestamp,
    'is_online': true,
  });

  // Also push to a history node in Realtime Database
  await db.ref('driver_history/$driverId').push().set({
    'lat': position.latitude,
    'lng': position.longitude,
    'speed': position.speed,
    'timestamp': ServerValue.timestamp,
  });
}
