import 'dart:convert';
import 'dart:io';

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../location_app_state_resolver.dart';
import 'location_log_entry.dart';

const String kLocationDebugBackgroundLogFileName =
    'location_debug_log_bg.jsonl';

Future<File> locationDebugBackgroundLogFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/$kLocationDebugBackgroundLogFileName');
}

Future<void> _ensureMeta({
  required void Function(String appVersion, String deviceName, String osVersion)
      onMeta,
}) async {
  if (Platform.isAndroid) {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion =
        '${packageInfo.version}+${packageInfo.buildNumber}';
    final deviceInfo = DeviceInfoPlugin();
    final a = await deviceInfo.androidInfo;
    final manufacturer = a.manufacturer.trim();
    final model = a.model.trim();
    final deviceName = manufacturer.isNotEmpty && model.isNotEmpty
        ? '$manufacturer $model'
        : model;
    final osVersion =
        'Android ${a.version.release} (SDK ${a.version.sdkInt})';
    onMeta(appVersion, deviceName, osVersion);
    return;
  }
  if (Platform.isIOS) {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion =
        '${packageInfo.version}+${packageInfo.buildNumber}';
    final deviceInfo = DeviceInfoPlugin();
    final i = await deviceInfo.iosInfo;
    onMeta(appVersion, i.name, 'iOS ${i.systemVersion}');
    return;
  }
  onMeta('?', Platform.localHostname, Platform.operatingSystem);
}

/// Called from the background location isolate only.
Future<void> appendLocationDebugLineFromTrackerData(
  BackgroundLocationUpdateData data,
) async {
  String appVersion = '?';
  String deviceName = '?';
  String osVersion = '?';
  try {
    await _ensureMeta(
      onMeta: (a, d, o) {
        appVersion = a;
        deviceName = d;
        osVersion = o;
      },
    );
  } catch (_) {}

  String appStateLabel;
  try {
    appStateLabel = await resolveAppStateForLocationSample();
  } catch (_) {
    appStateLabel = 'background';
  }

  final entry = LocationLogEntry(
    dateTime: DateTime.now(),
    latitude: data.lat,
    longitude: data.lon,
    appVersion: appVersion,
    deviceName: deviceName,
    osVersion: osVersion,
    appState: appStateLabel,
  );

  final file = await locationDebugBackgroundLogFile();
  final line = '${jsonEncode(entry.toJson())}\n';
  await file.writeAsString(line, mode: FileMode.append, flush: true);
}
