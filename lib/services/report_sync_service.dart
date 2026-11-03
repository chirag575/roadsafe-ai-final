import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/road_report.dart';
import 'report_storage.dart';

class ReportSyncService {
  ReportSyncService._();

  /// Uploads pending local reports to the signed-in user's private collection.
  /// Firestore's offline persistence queues writes while disconnected.
  static Future<int> syncPending() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final reports = await ReportStorage.getReports();
    var syncedCount = 0;
    for (final report in reports.where((item) => !item.synced)) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('road_reports')
          .doc(report.id)
          .set({
        'label': report.label,
        'confidence': report.confidence,
        'timestamp': Timestamp.fromDate(report.timestamp),
        'latitude': report.latitude,
        'longitude': report.longitude,
        'reviewStatus': report.reviewStatus,
      });
      await ReportStorage.updateReport(
        report.copyWith(synced: true),
      );
      syncedCount++;
    }

    final remoteReports = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('road_reports')
        .get();
    final localIds = (await ReportStorage.getReports())
        .map((report) => report.id)
        .toSet();
    for (final document in remoteReports.docs) {
      if (localIds.contains(document.id)) continue;
      final data = document.data();
      final timestamp = data['timestamp'];
      await ReportStorage.addReport(RoadReport(
        id: document.id,
        label: data['label'] as String? ?? 'Pothole',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
        timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        reviewStatus: data['reviewStatus'] as String? ?? 'needs review',
        synced: true,
      ));
      syncedCount++;
    }
    return syncedCount;
  }
}
