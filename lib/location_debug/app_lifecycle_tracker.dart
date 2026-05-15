import 'package:flutter/widgets.dart';

/// Keeps the current app lifecycle in sync for pairing with location fixes.
class AppLifecycleTracker with WidgetsBindingObserver {
  AppLifecycleTracker._();
  static final AppLifecycleTracker instance = AppLifecycleTracker._();

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Human-readable state: foreground, background, inactive, killed, unknown.
  String get currentStateLabel => _mapState(WidgetsBinding.instance.lifecycleState);

  /// Maps [state] for log rows (same as [currentStateLabel] for a concrete state).
  static String labelFor(AppLifecycleState state) => _mapState(state);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onLifecycleStateChanged?.call(state);
  }

  /// Set from [main] before [attach] for Firebase app-state sync and log ingest.
  static void Function(AppLifecycleState state)? onLifecycleStateChanged;

  static String _mapState(AppLifecycleState? state) {
    return switch (state) {
      AppLifecycleState.resumed => 'foreground',
      AppLifecycleState.inactive => 'inactive',
      AppLifecycleState.paused => 'background',
      AppLifecycleState.hidden => 'background',
      AppLifecycleState.detached => 'killed',
      null => 'unknown',
    };
  }
}