import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/i18n.dart';
import '../../models/report.dart';
import '../../models/enums.dart';
import '../../services/storage.dart';
import 'location_picker_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Report report;
  final File imageFile;

  const ReviewScreen({
    super.key,
    required this.report,
    required this.imageFile,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Category _selectedCategory;
  late Severity _selectedSeverity;
  late TextEditingController _notesController;
  late Report _currentReport;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
    _selectedCategory = _currentReport.category;
    _selectedSeverity = _currentReport.severity;
    _notesController = TextEditingController(text: _currentReport.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Update report with user selections
      final updatedReport = _currentReport.copyWith(
        category: _selectedCategory,
        severity: _selectedSeverity,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        updatedAt: DateTime.now().toIso8601String(),
      );

      // Save to storage
      await StorageService.saveReport(updatedReport);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(I18n.t('toast.reportSaved'))));

        // Navigate back to main screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('error.saving', {'0': e.toString()}))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          I18n.t('review.title'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitReport,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    I18n.t('review.submit'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced image preview
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(widget.imageFile, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 32),

              // AI Suggestion Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF0EA5E9).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              I18n.t('review.aiAnalysis'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                            ),
                            Text(
                              I18n.t('review.aiConfidence', {
                                '0':
                                    (_currentReport.aiSuggestion.confidence *
                                            100)
                                        .round()
                                        .toString(),
                              }),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: cs.onSurface.withOpacity(0.7),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.category,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currentReport
                                    .aiSuggestion
                                    .category
                                    .displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currentReport
                                    .aiSuggestion
                                    .severity
                                    .displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategory =
                                    _currentReport.aiSuggestion.category;
                                _selectedSeverity =
                                    _currentReport.aiSuggestion.severity;
                              });
                            },
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: Text(I18n.t('review.useSuggestion')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Navigate to manual editing screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationPickerScreen(
                                    initialLocation: _currentReport.location,
                                    initialAddress: _currentReport.address,
                                  ),
                                ),
                              ).then((result) {
                                if (result != null && mounted) {
                                  setState(() {
                                    // Update the report with new location
                                    _currentReport = _currentReport.copyWith(
                                      location: result['location'],
                                      address: result['address'],
                                    );
                                  });
                                }
                              });
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text(I18n.t('review.editManually')),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFF0EA5E9),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              foregroundColor: const Color(0xFF0EA5E9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Category Selection
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('review.category'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: Category.values.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? cs.primary : cs.outline,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: isSelected
                                ? cs.primary.withOpacity(0.1)
                                : cs.surface,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  category.displayName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? cs.primary
                                        : cs.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Severity Selection
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: cs.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('review.severity'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: Severity.values.map((severity) {
                        final isSelected = _selectedSeverity == severity;
                        final color = severity == Severity.high
                            ? const Color(0xFFDC2626)
                            : severity == Severity.medium
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF16A34A);
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? color : cs.outline,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: isSelected
                                ? color.withOpacity(0.1)
                                : cs.surface,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSeverity = severity;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 12, color: color),
                                    const SizedBox(width: 8),
                                    Text(
                                      severity.displayName,
                                      style: TextStyle(
                                        color: isSelected
                                            ? color
                                            : cs.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notes Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('review.notes'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: I18n.t('review.notesHint'),
                        hintStyle: TextStyle(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cs.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cs.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cs.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 4,
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Location Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: cs.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('review.location'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            // Navigate to location picker
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationPickerScreen(
                                  initialLocation: _currentReport.location,
                                  initialAddress: _currentReport.address,
                                ),
                              ),
                            ).then((result) {
                              if (result != null && mounted) {
                                setState(() {
                                  // Update the report with new location
                                  _currentReport = _currentReport.copyWith(
                                    location: result['location'],
                                    address: result['address'],
                                  );
                                });
                              }
                            });
                          },
                          icon: Icon(Icons.edit, size: 16, color: cs.primary),
                          label: Text(
                            I18n.t('btn.editLocation'),
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                size: 16,
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                I18n.t('review.coordinates'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: cs.onSurface.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_currentReport.location.lat.toStringAsFixed(6)}, ${_currentReport.location.lng.toStringAsFixed(6)}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: cs.onSurface,
                                  fontFamily: 'monospace',
                                ),
                          ),
                          if (_currentReport.location.accuracy != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.my_location,
                                  size: 16,
                                  color: cs.onSurface.withOpacity(0.7),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  I18n.t('review.accuracy', {
                                    '0': _currentReport.location.accuracy!
                                        .toStringAsFixed(1),
                                  }),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: cs.onSurface.withOpacity(0.7),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
