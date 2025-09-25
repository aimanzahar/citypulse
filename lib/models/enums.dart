import 'package:flutter/material.dart';

/// Categories for different types of issues that can be reported
enum Category {
  pothole,
  streetlight,
  signage,
  trash,
  drainage,
  other;

  /// Get the string key for localization
  String get key {
    switch (this) {
      case Category.pothole:
        return 'category.pothole';
      case Category.streetlight:
        return 'category.streetlight';
      case Category.signage:
        return 'category.signage';
      case Category.trash:
        return 'category.trash';
      case Category.drainage:
        return 'category.drainage';
      case Category.other:
        return 'category.other';
    }
  }

  /// Get the display name for this category
  String get displayName {
    switch (this) {
      case Category.pothole:
        return 'Pothole';
      case Category.streetlight:
        return 'Streetlight';
      case Category.signage:
        return 'Signage';
      case Category.trash:
        return 'Trash';
      case Category.drainage:
        return 'Drainage';
      case Category.other:
        return 'Other';
    }
  }

  /// Get all categories as a list
  static List<Category> get all => Category.values;
}

/// Severity levels for reported issues
enum Severity {
  high,
  medium,
  low;

  /// Get the string key for localization
  String get key {
    switch (this) {
      case Severity.high:
        return 'severity.high';
      case Severity.medium:
        return 'severity.medium';
      case Severity.low:
        return 'severity.low';
    }
  }

  /// Get the display name for this severity
  String get displayName {
    switch (this) {
      case Severity.high:
        return 'High';
      case Severity.medium:
        return 'Medium';
      case Severity.low:
        return 'Low';
    }
  }

  /// Get the color associated with this severity
  Color get color {
    switch (this) {
      case Severity.high:
        return const Color(0xFFD32F2F); // Red 700
      case Severity.medium:
        return const Color(0xFFF57C00); // Orange 700
      case Severity.low:
        return const Color(0xFF388E3C); // Green 700
    }
  }

  /// Get all severities as a list
  static List<Severity> get all => Severity.values;
}

/// Status of reported issues
enum Status {
  submitted,
  inProgress,
  fixed;

  /// Get the string key for localization
  String get key {
    switch (this) {
      case Status.submitted:
        return 'status.submitted';
      case Status.inProgress:
        return 'status.in_progress';
      case Status.fixed:
        return 'status.fixed';
    }
  }

  /// Get the display name for this status
  String get displayName {
    switch (this) {
      case Status.submitted:
        return 'Submitted';
      case Status.inProgress:
        return 'In Progress';
      case Status.fixed:
        return 'Fixed';
    }
  }

  /// Get the color associated with this status
  Color get color {
    switch (this) {
      case Status.submitted:
        return const Color(0xFF1976D2); // Blue 700
      case Status.inProgress:
        return const Color(0xFF7B1FA2); // Purple 700
      case Status.fixed:
        return const Color(0xFF455A64); // Blue Grey 700
    }
  }

  /// Get the next status in the cycle
  Status get next {
    switch (this) {
      case Status.submitted:
        return Status.inProgress;
      case Status.inProgress:
        return Status.fixed;
      case Status.fixed:
        return Status.submitted; // Cycle back to submitted
    }
  }

  /// Get all statuses as a list
  static List<Status> get all => Status.values;
}

/// Helper extensions for enum parsing
extension CategoryParsing on String {
  Category? toCategory() {
    switch (toLowerCase()) {
      case 'pothole':
        return Category.pothole;
      case 'streetlight':
        return Category.streetlight;
      case 'signage':
        return Category.signage;
      case 'trash':
        return Category.trash;
      case 'drainage':
        return Category.drainage;
      case 'other':
        return Category.other;
      default:
        return null;
    }
  }
}

extension SeverityParsing on String {
  Severity? toSeverity() {
    switch (toLowerCase()) {
      case 'high':
        return Severity.high;
      case 'medium':
        return Severity.medium;
      case 'low':
        return Severity.low;
      default:
        return null;
    }
  }
}

extension StatusParsing on String {
  Status? toStatus() {
    switch (toLowerCase()) {
      case 'submitted':
        return Status.submitted;
      case 'in_progress':
        return Status.inProgress;
      case 'fixed':
        return Status.fixed;
      default:
        return null;
    }
  }
}