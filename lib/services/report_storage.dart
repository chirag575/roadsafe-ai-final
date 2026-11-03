import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/road_report.dart';

class ReportStorage {
  ReportStorage._();

  static const _key = 'road_reports_v1';

  static Future<List<RoadReport>> getReports() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? const <String>[];
    return entries
        .map((entry) => RoadReport.fromMap(
              jsonDecode(entry) as Map<String, dynamic>,
            ))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> addReport(RoadReport report) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? <String>[];
    entries.insert(0, jsonEncode(report.toMap()));
    await preferences.setStringList(_key, entries);
  }

  static Future<void> deleteReport(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? <String>[];
    entries.removeWhere((entry) {
      final map = jsonDecode(entry) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await preferences.setStringList(_key, entries);
  }

  static Future<void> updateReport(RoadReport report) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? <String>[];
    final index = entries.indexWhere((entry) {
      final map = jsonDecode(entry) as Map<String, dynamic>;
      return map['id'] == report.id;
    });
    if (index < 0) return;
    entries[index] = jsonEncode(report.toMap());
    await preferences.setStringList(_key, entries);
  }
}
