import 'dart:async';

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_tracking/firebase_location_sync.dart';
import 'background_tracking/location_tracker_entrypoint.dart';
import 'tracking_prefs_keys.dart';
import 'firebase_options.dart';
import 'location_debug/app_lifecycle_tracker.dart';
import 'location_debug/location_logger.dart';
import 'login_screen.dart';
import 'driver_screen.dart';
import 'auth_service.dart';

Future<void> _persistAndSyncAppStateToFirebase(AppLifecycleState state) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final label = AppLifecycleTracker.labelFor(state);
    await prefs.setString(kLastAppStateLabelPrefsKey, label);
    final driverId = prefs.getString(kTrackingDriverIdPrefsKey);
    if (driverId != null && driverId.isNotEmpty) {
      await syncAppStateToFirebase(driverId, label);
    }
  } catch (e, st) {
    debugPrint('persist/sync app state: $e\n$st');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await BackgroundLocationTrackerManager.initialize(
    locationTrackerBackgroundCallback,
    config: const BackgroundLocationTrackerConfig(
      iOSConfig: IOSConfig(
        activityType: ActivityType.NAVIGATION,
        restartAfterKill: true,
      ),
      loggingEnabled: true,
      androidConfig: AndroidConfig(
          channelName: "high_importance_channel",
          trackingInterval: Duration(seconds: 3),
          distanceFilterMeters: 5,
          cancelTrackingActionText: "",
          enableCancelTrackingAction: false,
          notificationBody: 'App using your live location for ongoing ride'),
    ),
  );
  await LocationLogger.instance.restoreFromDisk();

  AppLifecycleTracker.onLifecycleStateChanged = (state) {
    unawaited(() async {
      await _persistAndSyncAppStateToFirebase(state);
      if (state == AppLifecycleState.resumed) {
        await LocationLogger.instance.ingestBackgroundTrackerLines();
      }
    }());
  };
  AppLifecycleTracker.instance.attach();
  final initialLifecycle = WidgetsBinding.instance.lifecycleState;
  if (initialLifecycle != null) {
    await _persistAndSyncAppStateToFirebase(initialLifecycle);
  }

  // Sync driverId to prefs if already logged in
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driverId', user.uid);
    await prefs.setString(kTrackingDriverIdPrefsKey, user.uid);
  }

  unawaited(LocationLogger.instance.ingestBackgroundTrackerLines());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracking',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const DriverScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
