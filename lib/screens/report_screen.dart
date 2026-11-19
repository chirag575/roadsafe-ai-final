import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/road_report.dart';
import '../services/report_storage.dart';
import '../services/report_sync_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Future<List<RoadReport>> _reports;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _reports = ReportStorage.getReports();
  }

  void _reload() {
    setState(() => _reports = ReportStorage.getReports());
  }

  Future<void> _addPhoto(RoadReport report) async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    await ReportStorage.updateReport(
      report.copyWith(photoPath: image.path, synced: false),
    );
    if (mounted) _reload();
  }

  Future<void> _review(RoadReport report, String status) async {
    await ReportStorage.updateReport(
      report.copyWith(reviewStatus: status, synced: false),
    );
    if (mounted) _reload();
  }

  Future<void> _sync() async {
    try {
      final count = await ReportSyncService.syncPending();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count == 0
            ? 'No pending reports, or sign in to sync.'
            : 'Synced $count report${count == 1 ? '' : 's'}.'),
      ));
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sync unavailable. Reports remain on this device.'),
      ));
    }
  }

  Future<void> _share(RoadReport report) async {
    final location = report.latitude == null || report.longitude == null
        ? 'Location unavailable'
        : 'Location: ${report.latitude}, ${report.longitude}\n'
          'Map: https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}';
    final details = 'RoadSafe AI Report\n'
        '${report.label} · ${report.reviewStatus}\n'
        'Confidence: ${(report.confidence * 100).round()}%\n'
        'Time: ${_dateLabel(report.timestamp)}\n\n$location';
    final photoPath = report.photoPath;
    if (photoPath == null) {
      await Share.share(details);
    } else {
      await Share.shareXFiles([XFile(photoPath)], text: details);
    }
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Reports'),
        actions: [
          IconButton(
            tooltip: 'Sync pending reports',
            onPressed: _sync,
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<RoadReport>>(
        future: _reports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load saved reports.'),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            );
          }
          final reports = snapshot.data ?? const <RoadReport>[];
          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 72, color: Colors.grey.shade500),
                    const SizedBox(height: 16),
                    const Text('No reports yet',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Detected potholes will be saved here on this device.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final report = reports[index];
                final hasLocation =
                    report.latitude != null && report.longitude != null;
                return Card(
                  child: ListTile(
                    leading: report.photoPath == null
                        ? const CircleAvatar(
                            child: Icon(Icons.warning_amber_rounded))
                        : FutureBuilder(
                            future: XFile(report.photoPath!).readAsBytes(),
                            builder: (context, imageSnapshot) {
                              final bytes = imageSnapshot.data;
                              return CircleAvatar(
                                backgroundImage:
                                    bytes == null ? null : MemoryImage(bytes),
                                child: bytes == null
                                    ? const Icon(Icons.image_outlined)
                                    : null,
                              );
                            },
                          ),
                    title: Text(report.label),
                    subtitle: Text(
                      '${_dateLabel(report.timestamp)}\n'
                      'Confidence: ${(report.confidence * 100).toStringAsFixed(0)}%\n'
                      '${hasLocation ? '${report.latitude!.toStringAsFixed(6)}, ${report.longitude!.toStringAsFixed(6)}' : 'Location unavailable'}\n'
                      'Review: ${report.reviewStatus}  •  ${report.synced ? 'Synced' : 'On device'}',
                    ),
                    isThreeLine: true,
                    onTap: () => _addPhoto(report),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Review report',
                      onSelected: (value) {
                        if (value == 'photo') {
                          _addPhoto(report);
                        } else if (value == 'delete') {
                          ReportStorage.deleteReport(report.id).then((_) {
                            if (mounted) _reload();
                          });
                        } else if (value == 'share') {
                          _share(report);
                        } else {
                          _review(report, value);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'confirmed', child: Text('Confirm hazard')),
                        PopupMenuItem(value: 'dismissed', child: Text('Dismiss detection')),
                        PopupMenuItem(value: 'needs review', child: Text('Needs review')),
                        PopupMenuItem(value: 'photo', child: Text('Take photo')),
                        PopupMenuItem(value: 'share', child: Text('Share report')),
                        PopupMenuItem(value: 'delete', child: Text('Delete report')),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
