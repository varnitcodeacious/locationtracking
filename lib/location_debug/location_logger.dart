import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'location_log_background_writer.dart';
import 'location_log_entry.dart';

/// Log of each GPS fix from the background tracker, persisted across restarts.
class LocationLogger extends ChangeNotifier {
  LocationLogger._();
  static final LocationLogger instance = LocationLogger._();

  static const int _maxEntries = 500;

  final List<LocationLogEntry> _entries = [];

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
      var droppedLifecycleRows = false;
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        if (item['isLifecycleOnly'] == true) {
          droppedLifecycleRows = true;
          continue;
        }
        loaded.add(LocationLogEntry.fromJson(item));
      }
      _entries
        ..clear()
        ..addAll(loaded);
      while (_entries.length > _maxEntries) {
        _entries.removeAt(0);
      }
      notifyListeners();
      if (droppedLifecycleRows) {
        await _persistToDisk();
      }
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

  /// Imports lines written by the tracker isolate from [locationDebugBackgroundLogFile].
  Future<void> ingestBackgroundTrackerLines() async {
    if (kIsWeb) return;
    try {
      final file = await locationDebugBackgroundLogFile();
      if (!await file.exists()) return;
      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        await file.delete();
        return;
      }
      var added = false;
      for (final raw in text.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map<String, dynamic> &&
              decoded['isLifecycleOnly'] != true) {
            _entries.add(LocationLogEntry.fromJson(decoded));
            added = true;
          }
        } catch (e) {
          debugPrint('LocationLogger ingest skip: $e');
        }
      }
      while (_entries.length > _maxEntries) {
        _entries.removeAt(0);
      }
      await file.delete();
      if (added) {
        notifyListeners();
        await _persistToDisk();
      }
    } catch (e, st) {
      debugPrint('LocationLogger ingest failed: $e\n$st');
    }
  }

  /// Removes all entries from memory and overwrites the persisted log file.
  Future<void> clearAllLogs() async {
    _entries.clear();
    notifyListeners();
    await _persistToDisk();
    if (kIsWeb) return;
    try {
      final bg = await locationDebugBackgroundLogFile();
      if (await bg.exists()) await bg.delete();
    } catch (e, st) {
      debugPrint('LocationLogger clear bg file failed: $e\n$st');
    }
  }
}