/// SharedPreferences keys shared by the main isolate and the location tracker.
const String kTrackingDriverIdPrefsKey = 'tracking_driver_id';

/// Last app-state label: `foreground`, `background`, or `swiped`.
/// Written from Dart on lifecycle changes, from Android `TaskRemovedWatcherService`
/// when the user clears the app from recents (started from `MainActivity`),
/// and read when logging background GPS rows / Firebase.
const String kLastAppStateLabelPrefsKey = 'last_app_state_label';
