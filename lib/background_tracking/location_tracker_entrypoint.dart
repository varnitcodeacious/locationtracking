import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../location_debug/location_log_background_writer.dart';
import '../tracking_prefs_keys.dart';
import 'firebase_location_sync.dart';

@pragma('vm:entry-point')
void locationTrackerBackgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
    (BackgroundLocationUpdateData data) async {
      print('data of location=$data');
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        final prefs = await SharedPreferences.getInstance();
        final driverId = prefs.getString(kTrackingDriverIdPrefsKey);
        if (driverId == null || driverId.isEmpty) {
          return;
        }
        await syncLocationUpdateToFirebase(data, driverId);
        await appendLocationDebugLineFromTrackerData(data);
      } catch (e, st) {
        // ignore: avoid_print
        print('locationTrackerBackgroundCallback: $e\n$st');
      }
    },
  );
}
