import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// On Android, asks the user to allow ignoring battery optimizations so
/// background location is not throttled. No-op on iOS / web / desktop.
Future<void> promptBatteryOptimizationIfNeeded(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return;

  final perm = Permission.ignoreBatteryOptimizations;
  var status = await perm.status;
  if (status.isGranted) return;

  if (!context.mounted) return;

  final shouldRequest = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Turn off battery optimization'),
      content: const Text(
        'Android may slow or pause location updates while this app is in the '
        'background. On the next screen, choose Allow so tracking stays reliable '
        'while you are on duty.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  if (shouldRequest != true || !context.mounted) return;

  status = await perm.request();
  if (!context.mounted) return;

  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Battery optimization may still limit background work. You can change '
          'this in Settings → Apps → this app → Battery.',
        ),
        action: SnackBarAction(
          label: 'Open settings',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }
}
