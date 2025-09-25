import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/i18n.dart';
import '../../models/report.dart';
import '../../models/enums.dart';
import '../../services/storage.dart';

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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.report.category;
    _selectedSeverity = widget.report.severity;
    _notesController = TextEditingController(text: widget.report.notes ?? '');
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
      final updatedReport = widget.report.copyWith(
        category: _selectedCategory,
        severity: _selectedSeverity,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        updatedAt: DateTime.now().toIso8601String(),
      );

      // Save to storage
      await StorageService.saveReport(updatedReport);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('toast.reportSaved'))),
        );

        // Navigate back to main screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving report: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('btn.submit')),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitReport,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(I18n.t('btn.submit')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),

            // AI Suggestion Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('label.aiSuggestion'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSuggestionChip(
                          widget.report.aiSuggestion.category.displayName,
                          Colors.blue.shade100,
                        ),
                        const SizedBox(width: 8),
                        _buildSuggestionChip(
                          widget.report.aiSuggestion.severity.displayName,
                          _getSeverityColor(widget.report.aiSuggestion.severity),
                        ),
                        const SizedBox(width: 8),
                        _buildSuggestionChip(
                          '${(widget.report.aiSuggestion.confidence * 100).round()}%',
                          Colors.grey.shade100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = widget.report.aiSuggestion.category;
                                _selectedSeverity = widget.report.aiSuggestion.severity;
                              });
                            },
                            child: Text(I18n.t('btn.useSuggestion')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Keep manual selections
                            },
                            child: Text(I18n.t('btn.keepManual')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Selection
            Text(
              I18n.t('label.category'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Category.values.map((category) {
                return ChoiceChip(
                  label: Text(category.displayName),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Severity Selection
            Text(
              I18n.t('label.severity'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Severity.values.map((severity) {
                return ChoiceChip(
                  label: Text(severity.displayName),
                  selected: _selectedSeverity == severity,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedSeverity = severity;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Notes
            Text(
              I18n.t('label.notes'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Add any additional notes...',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Location info
            Text(
              I18n.t('label.location'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${widget.report.location.lat.toStringAsFixed(6)}, '
              'Lng: ${widget.report.location.lng.toStringAsFixed(6)}',
            ),
            if (widget.report.location.accuracy != null)
              Text('Accuracy: ${widget.report.location.accuracy!.toStringAsFixed(1)}m'),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String label, Color color) {
    return Chip(
      label: Text(label),
      backgroundColor: color,
    );
  }

  Color _getSeverityColor(Severity severity) {
    switch (severity) {
      case Severity.high:
        return Colors.red.shade100;
      case Severity.medium:
        return Colors.orange.shade100;
      case Severity.low:
        return Colors.green.shade100;
    }
  }
}