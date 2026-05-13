class LocationLogEntry {
  const LocationLogEntry({
    required this.dateTime,
    required this.latitude,
    required this.longitude,
    required this.appVersion,
    required this.deviceName,
    required this.osVersion,
    required this.appState,
    this.isLifecycleOnly = false,
  });

  final DateTime dateTime;
  final double latitude;
  final double longitude;
  final String appVersion;
  final String deviceName;
  final String osVersion;
  final String appState;
  /// No GPS fix; row records an app lifecycle transition (e.g. killed/detached).
  final bool isLifecycleOnly;

  Map<String, dynamic> toJson() => {
        'dateTime': dateTime.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'appVersion': appVersion,
        'deviceName': deviceName,
        'osVersion': osVersion,
        'appState': appState,
        'isLifecycleOnly': isLifecycleOnly,
      };

  factory LocationLogEntry.fromJson(Map<String, dynamic> json) {
    return LocationLogEntry(
      dateTime: DateTime.parse(json['dateTime'] as String).toLocal(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      appVersion: json['appVersion'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      osVersion: json['osVersion'] as String? ?? '',
      appState: json['appState'] as String? ?? '',
      isLifecycleOnly: json['isLifecycleOnly'] as bool? ?? false,
    );
  }
}
