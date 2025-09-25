import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/report.dart';

/// Service for persisting reports and managing local storage
class StorageService {
  static const String _reportsKey = 'reports_v1';

  /// Get all reports from storage
  static Future<List<Report>> getReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getString(_reportsKey);

      if (reportsJson == null || reportsJson.isEmpty) {
        return [];
      }

      final List<dynamic> reportsList = json.decode(reportsJson);
      return reportsList.map((json) => Report.fromJson(json)).toList();
    } catch (e) {
      print('Error loading reports: $e');
      return [];
    }
  }

  /// Save a single report to storage
  static Future<bool> saveReport(Report report) async {
    try {
      final reports = await getReports();
      final existingIndex = reports.indexWhere((r) => r.id == report.id);

      if (existingIndex >= 0) {
        reports[existingIndex] = report;
      } else {
        reports.add(report);
      }

      return await _saveReportsList(reports);
    } catch (e) {
      print('Error saving report: $e');
      return false;
    }
  }

  /// Delete a report from storage
  static Future<bool> deleteReport(String reportId) async {
    try {
      final reports = await getReports();
      final updatedReports = reports.where((r) => r.id != reportId).toList();

      // Delete photo file if it exists
      if (kIsWeb) {
        // On web, base64 is stored in memory, no file to delete
      } else {
        await _deletePhotoFile(reportId);
      }

      return await _saveReportsList(updatedReports);
    } catch (e) {
      print('Error deleting report: $e');
      return false;
    }
  }

  /// Clear all reports from storage
  static Future<bool> clearAllReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_reportsKey);

      // Delete all photo files
      if (!kIsWeb) {
        await _deleteAllPhotoFiles();
      }

      return true;
    } catch (e) {
      print('Error clearing reports: $e');
      return false;
    }
  }

  /// Save reports list to SharedPreferences
  static Future<bool> _saveReportsList(List<Report> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert reports to JSON, excluding photo data for mobile
      final reportsForStorage = reports.map((report) {
        final json = report.toJson();
        if (!kIsWeb) {
          // On mobile, remove base64Photo to save space
          json.remove('base64Photo');
        }
        return json;
      }).toList();

      final reportsJson = json.encode(reportsForStorage);
      return await prefs.setString(_reportsKey, reportsJson);
    } catch (e) {
      print('Error saving reports list: $e');
      return false;
    }
  }

  /// Get the photo file for a report
  static Future<File?> getPhotoFile(String reportId) async {
    if (kIsWeb) return null;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photoFile = File('${appDir.path}/$reportId.jpg');

      if (await photoFile.exists()) {
        return photoFile;
      }
      return null;
    } catch (e) {
      print('Error getting photo file: $e');
      return null;
    }
  }

  /// Save photo file for a report
  static Future<bool> savePhotoFile(String reportId, List<int> photoBytes) async {
    if (kIsWeb) return false;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photoFile = File('${appDir.path}/$reportId.jpg');
      await photoFile.writeAsBytes(photoBytes);
      return true;
    } catch (e) {
      print('Error saving photo file: $e');
      return false;
    }
  }

  /// Delete photo file for a report
  static Future<bool> _deletePhotoFile(String reportId) async {
    if (kIsWeb) return true;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photoFile = File('${appDir.path}/$reportId.jpg');

      if (await photoFile.exists()) {
        await photoFile.delete();
      }
      return true;
    } catch (e) {
      print('Error deleting photo file: $e');
      return false;
    }
  }

  /// Delete all photo files
  static Future<void> _deleteAllPhotoFiles() async {
    if (kIsWeb) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final reports = await getReports();

      for (final report in reports) {
        final photoFile = File('${appDir.path}/${report.id}.jpg');
        if (await photoFile.exists()) {
          await photoFile.delete();
        }
      }
    } catch (e) {
      print('Error deleting all photo files: $e');
    }
  }

  /// Get storage statistics
  static Future<StorageStats> getStorageStats() async {
    try {
      final reports = await getReports();
      int photoFilesSize = 0;

      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        final reportsDir = Directory(appDir.path);

        if (await reportsDir.exists()) {
          final files = reportsDir.listSync().whereType<File>();
          photoFilesSize = files
              .where((file) => file.path.endsWith('.jpg'))
              .fold(0, (sum, file) => sum + file.lengthSync());
        }
      }

      return StorageStats(
        reportCount: reports.length,
        photoFilesSize: photoFilesSize,
      );
    } catch (e) {
      print('Error getting storage stats: $e');
      return StorageStats(reportCount: 0, photoFilesSize: 0);
    }
  }
}

/// Storage statistics model
class StorageStats {
  final int reportCount;
  final int photoFilesSize; // in bytes

  const StorageStats({
    required this.reportCount,
    required this.photoFilesSize,
  });

  String get formattedPhotoSize {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = photoFilesSize.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}