import 'package:shared_preferences/shared_preferences.dart';

import 'tracking_prefs_keys.dart';

/// Used only from the location tracker isolate (Firebase + debug JSONL).
///
/// Do **not** read [WidgetsBinding] here: in a secondary isolate it often
/// stays `resumed`, which wrongly labels background GPS as `foreground`.
/// Use prefs updated on the main isolate from [AppLifecycleTracker].
Future<String> resolveAppStateForLocationSample() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final raw = prefs.getString(kLastAppStateLabelPrefsKey);
  if (raw != null && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return 'unknown';
}
