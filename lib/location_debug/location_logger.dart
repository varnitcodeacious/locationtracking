import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app_lifecycle_tracker.dart';
import 'location_log_entry.dart';

/// Log of each location fix (and lifecycle transitions), persisted across restarts.
class LocationLogger extends ChangeNotifier {
  LocationLogger._();
  static final LocationLogger instance = LocationLogger._();

  static const int _maxEntries = 200;

  final List<LocationLogEntry> _entries = [];

  String _appVersion = '';
  String _deviceName = '';
  String _osVersion = '';
  bool _metaLoaded = false;

  List<LocationLogEntry> get entries => List.unmodifiable(_entries);

  Future<File> _persistFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/location_debug_log.json');
  }

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> restoreFromDisk() async {
    if (kIsWeb) return;
    try {
      final file = await _persistFile();
      if (!await file.exists()) return;
      final text = await file.readAsString();
      if (text.isEmpty) return;
      final decoded = jsonDecode(text);
      if (decoded is! List<dynamic>) return;
      final loaded = <LocationLogEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          loaded.add(LocationLogEntry.fromJson(item));
        }
      }
      _entries
        ..clear()
        ..addAll(loaded);
      while (_entries.length > _maxEntries) {
        _entries.removeAt(0);
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('LocationLogger restore failed: $e\n$st');
    }
  }

  Future<void> _persistToDisk() async {
    if (kIsWeb) return;
    try {
      final file = await _persistFile();
      final list = _entries.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e, st) {
      debugPrint('LocationLogger persist failed: $e\n$st');
    }
  }

  Future<void> _ensureDeviceMeta() async {
    if (_metaLoaded) return;

    if (kIsWeb) {
      _appVersion = 'web';
      _deviceName = 'Web';
      _osVersion = 'Web';
      _metaLoaded = true;
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await deviceInfo.androidInfo;
      final manufacturer = a.manufacturer.trim();
      final model = a.model.trim();
      _deviceName =
          manufacturer.isNotEmpty && model.isNotEmpty ? '$manufacturer $model' : model;
      _osVersion = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
    } else if (Platform.isIOS) {
      final i = await deviceInfo.iosInfo;
      _deviceName = i.name;
      _osVersion = 'iOS ${i.systemVersion}';
    } else {
      _deviceName = Platform.localHostname;
      _osVersion = Platform.operatingSystem;
    }

    _metaLoaded = true;
  }

  /// Records [state] as a row (no lat/lng). `detached` maps to `killed` when the OS delivers it.
  /// Abrupt process kill usually does **not** run Dart; those exits leave no row.
  Future<void> logLifecycleState(AppLifecycleState state) async {
    try {
      await _ensureDeviceMeta();
    } catch (e, st) {
      debugPrint('LocationLogger device meta failed: $e\n$st');
      if (!_metaLoaded) {
        _appVersion = '?';
        _deviceName = '?';
        _osVersion = '?';
        _metaLoaded = true;
      }
    }

    final label = AppLifecycleTracker.labelFor(state);
    final entry = LocationLogEntry(
      dateTime: DateTime.now(),
      latitude: 0,
      longitude: 0,
      appVersion: _appVersion,
      deviceName: _deviceName,
      osVersion: _osVersion,
      appState: label,
      isLifecycleOnly: true,
    );

    _entries.add(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
    await _persistToDisk();
  }

  Future<void> logPosition(Position position) async {
    try {
      await _ensureDeviceMeta();
    } catch (e, st) {
      debugPrint('LocationLogger device meta failed: $e\n$st');
      if (!_metaLoaded) {
        _appVersion = '?';
        _deviceName = '?';
        _osVersion = '?';
        _metaLoaded = true;
      }
    }

    final entry = LocationLogEntry(
      dateTime: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      appVersion: _appVersion,
      deviceName: _deviceName,
      osVersion: _osVersion,
      appState: AppLifecycleTracker.instance.currentStateLabel,
    );

    _entries.add(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
    await _persistToDisk();
  }

  /// Removes all entries from memory and overwrites the persisted log file.
  Future<void> clearAllLogs() async {
    _entries.clear();
    notifyListeners();
    await _persistToDisk();
  }
}
