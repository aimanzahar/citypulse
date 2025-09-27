import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/report.dart';
import '../models/enums.dart' as enums;
import '../services/storage.dart';
import '../services/api_service.dart';
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
    final placeholder = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image, color: Colors.grey.shade600),
    );

    // Prefer backend-provided image URL when available
    if (report.imageUrl != null && report.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          report.imageUrl!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

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
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
        );
      }
    }

    return placeholder;
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(I18n.t('btn.no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(I18n.t('btn.yes')),
          ),
        ],
      ),
    );

    if (ok == true) {
      bool success = false;
      try {
        success = await ApiService.deleteTicket(report.id);
      } catch (e) {
        print('Error deleting via API: $e');
        success = false;
      }

      // Fallback to local delete if API delete fails
      if (!success) {
        success = await StorageService.deleteReport(report.id);
      }

      if (success) {
        if (onDeleted != null) {
          onDeleted!();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(I18n.t('toast.reportDeleted'))),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(I18n.t('error.saving', {'0': 'Failed to delete report'}))),
          );
        }
      }
    }
  }

  Color _getStatusColor(enums.Status status) {
    switch (status) {
      case enums.Status.submitted:
        return const Color(0xFF2563EB);
      case enums.Status.inProgress:
        return const Color(0xFF64748B);
      case enums.Status.fixed:
        return const Color(0xFF16A34A);
    }
  }

  IconData _getCategoryIcon(enums.Category category) {
    switch (category) {
      case enums.Category.pothole:
        return Icons.warning;
      case enums.Category.streetlight:
        return Icons.lightbulb;
      case enums.Category.signage:
        return Icons.traffic;
      case enums.Category.trash:
        return Icons.delete;
      case enums.Category.drainage:
        return Icons.water;
      case enums.Category.other:
        return Icons.category;
    }
  }

  Color _getSeverityColorValue(enums.Severity severity) {
    switch (severity) {
      case enums.Severity.high:
        return const Color(0xFFDC2626);
      case enums.Severity.medium:
        return const Color(0xFFF59E0B);
      case enums.Severity.low:
        return const Color(0xFF16A34A);
    }
  }

  IconData _getStatusIcon(enums.Status status) {
    switch (status) {
      case enums.Status.submitted:
        return Icons.send;
      case enums.Status.inProgress:
        return Icons.build;
      case enums.Status.fixed:
        return Icons.check_circle;
    }
  }

  Future<void> _cycleStatus(BuildContext context) async {
    final next = report.status.next;
    final updated = report.copyWith(
      status: next,
      updatedAt: DateTime.now().toIso8601String(),
    );
    final ok = await StorageService.saveReport(updated);
    if (ok) {
      if (onUpdated != null) {
        onUpdated!(updated);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(I18n.t('btn.changeStatus'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced thumbnail
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildThumbnail(),
                  ),
                ),
                const SizedBox(width: 16),
                // Enhanced content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with category icon
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(
                              enums.Category.values[report.category.index],
                            ),
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              report.category.displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Submitted by (if available)
                      if (report.submittedBy != null) ...[
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: cs.onSurface.withOpacity(0.6)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Submitted by ${report.submittedBy}',
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Status indicators
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getSeverityColorValue(
                                report.severity,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getSeverityColorValue(report.severity),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 14,
                                  color: _getSeverityColorValue(
                                    report.severity,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  report.severity.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getSeverityColorValue(
                                      report.severity,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                report.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(report.status),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(report.status),
                                  size: 14,
                                  color: _getStatusColor(report.status),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  report.status.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(report.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Time and location info
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(report.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.address != null && report.address!.isNotEmpty
                                  ? report.address!
                                  : '${report.location.lat.toStringAsFixed(4)}, ${report.location.lng.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.6),
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Enhanced menu button
                PopupMenuButton<int>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: cs.surface,
                  elevation: 4,
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
                    PopupMenuItem(
                      value: 0,
                      child: Row(
                        children: [
                          const Icon(Icons.visibility),
                          const SizedBox(width: 8),
                          Text(I18n.t('btn.viewDetails')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          const Icon(Icons.update),
                          const SizedBox(width: 8),
                          Text(I18n.t('report.updateStatus')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            I18n.t('report.delete'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
