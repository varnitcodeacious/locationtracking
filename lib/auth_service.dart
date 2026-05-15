import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tracking_prefs_keys.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Stream of auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign up with email and password
  Future<User?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await _updateDriverData(user, name: name);
      }
      return user;
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await _updateDriverData(user);
      }
      return user;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driverId');
    await prefs.remove(kTrackingDriverIdPrefsKey);
    await _auth.signOut();
  }

  // Helper to update driver data in Realtime Database and Local Storage
  Future<void> _updateDriverData(User user, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driverId', user.uid);
    await prefs.setString(kTrackingDriverIdPrefsKey, user.uid);

    Map<String, dynamic> data = {
      'driver_id': user.uid,
      'email': user.email,
      'last_seen': ServerValue.timestamp,
    };
    if (name != null) data['name'] = name;

    await _db.ref('drivers/${user.uid}').update(data);
  }

  String? get currentDriverId => _auth.currentUser?.uid;
}
