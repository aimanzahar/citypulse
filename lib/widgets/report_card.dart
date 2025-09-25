import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/report.dart';
import '../services/storage.dart';
import 'severity_badge.dart';
import 'status_badge.dart';
import '../l10n/i18n.dart';

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback? onView;
  final VoidCallback? onDeleted;
  final ValueChanged<Report>? onUpdated;

  const ReportCard({
    super.key,
    required this.report,
    this.onView,
    this.onDeleted,
    this.onUpdated,
  });

  Widget _buildThumbnail() {
    if (kIsWeb && report.base64Photo != null) {
      try {
        final bytes = base64Decode(report.base64Photo!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover),
        );
      } catch (_) {}
    } else if (report.photoPath != null) {
      final file = File(report.photoPath!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image, color: Colors.grey.shade600),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('confirm.deleteReport.title')),
        content: Text(I18n.t('confirm.deleteReport.message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t('btn.no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t('btn.yes'))),
        ],
      ),
    );

    if (ok == true) {
      final success = await StorageService.deleteReport(report.id);
      if (success) {
        if (onDeleted != null) onDeleted!();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('toast.reportDeleted'))));
      }
    }
  }

  Future<void> _cycleStatus(BuildContext context) async {
    final next = report.status.next;
    final updated = report.copyWith(status: next, updatedAt: DateTime.now().toIso8601String());
    final ok = await StorageService.saveReport(updated);
    if (ok) {
      if (onUpdated != null) onUpdated!(updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('btn.changeStatus'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: _buildThumbnail(),
        title: Text(report.category.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                SeverityBadge(severity: report.severity, small: true),
                const SizedBox(width: 8),
                StatusBadge(status: report.status),
                const SizedBox(width: 8),
                Text(_formatTime(report.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<int>(
          onSelected: (v) async {
            if (v == 0) {
              if (onView != null) onView!();
            } else if (v == 1) {
              await _cycleStatus(context);
            } else if (v == 2) {
              await _confirmAndDelete(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 0, child: Text(I18n.t('btn.view'))),
            PopupMenuItem(value: 1, child: Text(I18n.t('btn.changeStatus'))),
            PopupMenuItem(value: 2, child: Text(I18n.t('btn.delete'))),
          ],
        ),
      ),
    );
  }
}