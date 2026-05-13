import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_service.dart';
import 'native_location_service.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final AuthService _authService = AuthService();
  final NativeLocationService _locationService = NativeLocationService();
  Timer? _statusTimer;
  bool _isOnDuty = false;
  Map<String, dynamic>? _lastLocation;

  @override
  void initState() {
    super.initState();
    _loadNativeLocationState();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isOnDuty) _loadNativeLocationState();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleDuty(bool value) async {
    try {
      if (value) {
        final driverId = _authService.currentDriverId;
        if (driverId == null) {
          throw Exception('Driver is not signed in.');
        }

        final hasPermission = await _ensureLocationPermissions();
        if (!hasPermission) {
          throw Exception('Location permission is required to go on duty.');
        }

        await _locationService.start(driverId);
      } else {
        await _locationService.stop();
      }

      if (mounted) {
        setState(() => _isOnDuty = value);
        await _loadNativeLocationState();
      }
    } catch (e) {
      debugPrint('Error toggling duty: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isOnDuty = !value);
      }
    }
  }

  Future<void> _loadNativeLocationState() async {
    final status = await _locationService.status();
    if (!mounted) return;

    final lat = status['lat'];
    final lng = status['lng'];
    setState(() {
      _isOnDuty = status['isRunning'] == true;
      _lastLocation = lat != null && lng != null
          ? {'lat': lat, 'lng': lng}
          : null;
      print('_lastLocation $_lastLocation');
    });
  }

  Future<bool> _ensureLocationPermissions() async {
    final whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) return false;

    await Permission.notification.request();

    final always = await Permission.locationAlways.request();
    return always.isGranted || whenInUse.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (_isOnDuty) await _toggleDuty(false);
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isOnDuty ? 'On Duty' : 'Off Duty',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Switch(value: _isOnDuty, onChanged: (val) => _toggleDuty(val)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Driver ID: ${_authService.currentDriverId ?? "N/A"}'),
            const SizedBox(height: 12),
            if (_lastLocation != null) ...[
              const Text(
                'Live Location:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Lat: ${_lastLocation!['lat']?.toStringAsFixed(6)}'),
              Text('Lng: ${_lastLocation!['lng']?.toStringAsFixed(6)}'),
            ] else if (_isOnDuty) ...[
              const Text('Waiting for location updates...'),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
