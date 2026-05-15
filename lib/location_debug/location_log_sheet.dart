import 'dart:async';
import 'dart:io' show File;

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'location_log_entry.dart';
import 'location_logger.dart';

class LocationLogSheet extends StatefulWidget {
  const LocationLogSheet({super.key});

  @override
  State<LocationLogSheet> createState() => _LocationLogSheetState();
}

class _LocationLogSheetState extends State<LocationLogSheet> {
  bool _exporting = false;
  Timer? _ingestTimer;

  @override
  void initState() {
    super.initState();
    unawaited(LocationLogger.instance.ingestBackgroundTrackerLines());
    _ingestTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(LocationLogger.instance.ingestBackgroundTrackerLines());
    });
  }

  @override
  void dispose() {
    _ingestTimer?.cancel();
    super.dispose();
  }

  Future<void> _exportExcel(List<LocationLogEntry> entries) async {
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No rows to export yet.')),
        );
      }
      return;
    }

    setState(() => _exporting = true);
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.tables.keys.first;
      final sheet = excel[sheetName];
      sheet.appendRow([
        TextCellValue('DateTime'),
        TextCellValue('Latitude'),
        TextCellValue('Longitude'),
        TextCellValue('App version'),
        TextCellValue('Device'),
        TextCellValue('OS'),
        TextCellValue('App state'),
      ]);
      for (final e in entries) {
        sheet.appendRow([
          TextCellValue(e.dateTime.toIso8601String()),
          TextCellValue(e.latitude.toStringAsFixed(6)),
          TextCellValue(e.longitude.toStringAsFixed(6)),
          TextCellValue(e.appVersion),
          TextCellValue(e.deviceName),
          TextCellValue(e.osVersion),
          TextCellValue(e.appState),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw StateError('Could not encode spreadsheet.');
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/location_logs_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Location debug log',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmClearLogs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text(
          'Every row will be removed from this device (memory and saved file).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await LocationLogger.instance.clearAllLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logger = LocationLogger.instance;

    return AnimatedBuilder(
      animation: logger,
      builder: (context, _) {
        final entries = logger.entries;
        final height = MediaQuery.sizeOf(context).height * 0.85;

        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Logs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exporting ? null : () => _exportExcel(entries),
                          icon: _exporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download),
                          label: Text(
                            _exporting ? 'Exporting…' : 'Download Excel (.xlsx)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exporting ? null : _confirmClearLogs,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear logs'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('No location rows logged yet.'))
                      : Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStatePropertyAll(
                                  Theme.of(context).colorScheme.surfaceContainerHighest,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Date / time')),
                                  DataColumn(label: Text('Lat, Lng')),
                                  DataColumn(label: Text('App state')),
                                  DataColumn(label: Text('App version')),
                                  DataColumn(label: Text('Device')),
                                  DataColumn(label: Text('OS')),
                                ],
                                rows: [
                                  for (final e in entries.reversed)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            e.dateTime.toLocal().toString(),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${e.latitude.toStringAsFixed(5)}, ${e.longitude.toStringAsFixed(5)}',
                                          ),
                                        ),
                                        DataCell(Text(e.appState)),
                                        DataCell(Text(e.appVersion)),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 140),
                                            child: Text(
                                              e.deviceName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(e.osVersion)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}