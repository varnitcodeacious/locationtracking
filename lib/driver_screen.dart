import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'auth_service.dart';
import 'background_tracking/background_location_tracking_service.dart';
import 'battery_optimization_request.dart';
import 'location_debug/location_log_sheet.dart';
import 'location_debug/location_logger.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final AuthService _authService = AuthService();
  final BackgroundLocationTrackingService _locationService =
      BackgroundLocationTrackingService();
  Timer? _statusTimer;
  bool _isOnDuty = false;
  bool _dutyBusy = false;
  bool _permBusy = false;

  bool _locationServiceEnabled = false;
  PermissionStatus _whenInUse = PermissionStatus.denied;
  PermissionStatus _always = PermissionStatus.denied;
  PermissionStatus _batteryOptimizationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    pakageInfoLog();
    _refreshFromService();
    _refreshPermissionStatus();

    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _refreshPermissionStatus();
      if (_isOnDuty) {
        _refreshFromService();
        unawaited(LocationLogger.instance.ingestBackgroundTrackerLines());
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
  String? _appVersion;
Future<void> pakageInfoLog() async {
  final packageInfo = await PackageInfo.fromPlatform();
  _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
}
  Future<void> _refreshPermissionStatus() async {
    final svc = await Permission.location.serviceStatus;
    final whenInUse = Platform.isIOS
        ? await Permission.locationWhenInUse.status
        : await Permission.location.status;
    final always = await Permission.locationAlways.status;
    PermissionStatus battery = PermissionStatus.denied;
    if (!kIsWeb && Platform.isAndroid) {
      battery = await Permission.ignoreBatteryOptimizations.status;
    } else {
      battery = PermissionStatus.granted;
    }
    if (!mounted) return;
    setState(() {
      _locationServiceEnabled = svc == ServiceStatus.enabled;
      _whenInUse = whenInUse;
      _always = always;
      _batteryOptimizationStatus = battery;
    });
  }

  Future<void> _refreshFromService() async {
    final status = await _locationService.status();
    if (!mounted) return;
    setState(() {
      _isOnDuty = status['isRunning'] == true;
    });
  }

  bool get _blockingBusy => _dutyBusy || _permBusy;

  String get _locationPermissionLabel {
    if (_always.isGranted) {
      return 'Always / All the time';
    }
    if (_whenInUse.isGranted) {
      return 'While in use only';
    }
    if (_whenInUse.isPermanentlyDenied || _always.isPermanentlyDenied) {
      return 'Denied permanently';
    }
    if (_whenInUse.isDenied && !_whenInUse.isGranted) {
      return 'Denied';
    }
    return 'Unknown';
  }

  String get _batteryLabel {
    if (kIsWeb || !Platform.isAndroid) return 'Not applicable (not Android)';
    switch (_batteryOptimizationStatus) {
      case PermissionStatus.granted:
        return 'Unrestricted (ignored for this app)';
      case PermissionStatus.denied:
        return 'Restricted (battery optimization on)';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently denied / restricted';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }

  Future<void> _requestPermissionsTap() async {
    if (_permBusy) return;
    setState(() => _permBusy = true);
    try {
      await _locationService.ensureLocationPermissionForTracking();
      if (!mounted) return;
      await promptBatteryOptimizationIfNeeded(context);
      if (!mounted) return;
      await _refreshPermissionStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission steps finished. Check status below.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission: $e')),
        );
        await _refreshPermissionStatus();
      }
    } finally {
      if (mounted) setState(() => _permBusy = false);
    }
  }

  Future<void> _toggleDuty(bool value) async {
    if (_dutyBusy) return;
    setState(() => _dutyBusy = true);
    try {
      if (value) {
        final driverId = _authService.currentDriverId;
        if (driverId == null) {
          throw Exception('Driver is not signed in.');
        }
        await _locationService.start(driverId);
      } else {
        await _locationService.stop();
      }
      if (mounted) await _refreshFromService();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        await _refreshFromService();
      }
    } finally {
      if (mounted) setState(() => _dutyBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _blockingBusy
            ? null
            : () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => const LocationLogSheet(),
                );
              },
        icon: const Icon(Icons.download),
        label: const Text('Export logs'),
      ),
      appBar: AppBar(
        title: const Text('Driver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _blockingBusy
                ? null
                : () async {
                    if (_isOnDuty) await _toggleDuty(false);
                    await _authService.signOut();
                  },
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Permissions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Device location (GPS): '
                  '${_locationServiceEnabled ? "ON" : "OFF"}'),
              Text('Location access: $_locationPermissionLabel'),
              Text('Battery optimization: $_batteryLabel'),
              Text('App version: $_appVersion'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _permBusy ? null : _requestPermissionsTap,
                icon: _permBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shield_outlined),
                label: Text(
                  _permBusy ? 'Requesting…' : 'Request permissions',
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Tracking',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOnDuty ? 'On' : 'Off',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Switch(
                    value: _isOnDuty,
                    onChanged: _blockingBusy ? null : (val) => _toggleDuty(val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Driver ID: ${_authService.currentDriverId ?? "N/A"}'),
            ],
          ),
          if (_blockingBusy)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.35),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
