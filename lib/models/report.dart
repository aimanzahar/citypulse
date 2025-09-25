import 'dart:math';
import 'enums.dart';

/// Represents a citizen report for community issues
class Report {
  /// Unique identifier for the report
  final String id;

  /// Category of the issue
  final Category category;

  /// Severity level of the issue
  final Severity severity;

  /// Current status of the report
  final Status status;

  /// File path to the photo on mobile devices
  final String? photoPath;

  /// Base64 encoded photo for web platform
  final String? base64Photo;

  /// Geographic location where the issue was reported
  final LocationData location;

  /// When the report was created (ISO string)
  final String createdAt;

  /// When the report was last updated (ISO string)
  final String updatedAt;

  /// Unique device identifier
  final String deviceId;

  /// Optional notes from the user
  final String? notes;

  /// Address or location description (placeholder for future use)
  final String? address;

  /// Source of the photo ("camera" or "gallery")
  final String source;

  /// Whether the report can be edited
  final bool editable;

  /// Whether the report can be deleted
  final bool deletable;

  /// AI suggestion for category and severity
  final AISuggestion aiSuggestion;

  /// Schema version for data migration
  final int schemaVersion;

  const Report({
    required this.id,
    required this.category,
    required this.severity,
    required this.status,
    this.photoPath,
    this.base64Photo,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
    this.notes,
    this.address,
    required this.source,
    this.editable = true,
    this.deletable = true,
    required this.aiSuggestion,
    this.schemaVersion = 1,
  });

  /// Generate a simple unique ID
  static String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return '$timestamp$random';
  }

  /// Create a new report with current timestamp and generated ID
  factory Report.create({
    required Category category,
    required Severity severity,
    required LocationData location,
    String? photoPath,
    String? base64Photo,
    String? notes,
    required String source,
    required String deviceId,
    required AISuggestion aiSuggestion,
  }) {
    final now = DateTime.now().toIso8601String();
    return Report(
      id: _generateId(),
      category: category,
      severity: severity,
      status: Status.submitted,
      photoPath: photoPath,
      base64Photo: base64Photo,
      location: location,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
      notes: notes,
      source: source,
      aiSuggestion: aiSuggestion,
    );
  }

  /// Create a copy of this report with updated fields
  Report copyWith({
    Category? category,
    Severity? severity,
    Status? status,
    String? photoPath,
    String? base64Photo,
    LocationData? location,
    String? updatedAt,
    String? notes,
    String? address,
    bool? editable,
    bool? deletable,
    AISuggestion? aiSuggestion,
  }) {
    return Report(
      id: id,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      photoPath: photoPath ?? this.photoPath,
      base64Photo: base64Photo ?? this.base64Photo,
      location: location ?? this.location,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId,
      notes: notes ?? this.notes,
      address: address ?? this.address,
      source: source,
      editable: editable ?? this.editable,
      deletable: deletable ?? this.deletable,
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
      schemaVersion: schemaVersion,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'severity': severity.name,
      'status': status.key,
      'photoPath': photoPath,
      'base64Photo': base64Photo,
      'location': {
        'lat': location.lat,
        'lng': location.lng,
        'accuracy': location.accuracy,
      },
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deviceId': deviceId,
      'notes': notes,
      'address': address,
      'source': source,
      'editable': editable,
      'deletable': deletable,
      'aiSuggestion': {
        'category': aiSuggestion.category.name,
        'severity': aiSuggestion.severity.name,
        'confidence': aiSuggestion.confidence,
      },
      'schemaVersion': schemaVersion,
    };
  }

  /// Create from JSON for loading from storage
  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      category: (json['category'] as String).toCategory() ?? Category.other,
      severity: (json['severity'] as String).toSeverity() ?? Severity.medium,
      status: (json['status'] as String).toStatus() ?? Status.submitted,
      photoPath: json['photoPath'] as String?,
      base64Photo: json['base64Photo'] as String?,
      location: LocationData(
        lat: (json['location']['lat'] as num).toDouble(),
        lng: (json['location']['lng'] as num).toDouble(),
        accuracy: json['location']['accuracy'] == null
            ? null
            : (json['location']['accuracy'] as num).toDouble(),
      ),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      deviceId: json['deviceId'] as String,
      notes: json['notes'] as String?,
      address: json['address'] as String?,
      source: json['source'] as String,
      editable: json['editable'] as bool? ?? true,
      deletable: json['deletable'] as bool? ?? true,
      aiSuggestion: AISuggestion(
        category: (json['aiSuggestion']['category'] as String).toCategory() ?? Category.other,
        severity: (json['aiSuggestion']['severity'] as String).toSeverity() ?? Severity.medium,
        confidence: (json['aiSuggestion']['confidence'] as num).toDouble(),
      ),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }

  @override
  String toString() {
    return 'Report(id: $id, category: ${category.name}, severity: ${severity.name}, status: ${status.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Report && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Represents geographic location data
class LocationData {
  /// Latitude coordinate
  final double lat;

  /// Longitude coordinate
  final double lng;

  /// Accuracy of the location in meters (optional)
  final double? accuracy;

  const LocationData({
    required this.lat,
    required this.lng,
    this.accuracy,
  });

  @override
  String toString() {
    return 'LocationData(lat: $lat, lng: $lng, accuracy: $accuracy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationData &&
        other.lat == lat &&
        other.lng == lng &&
        other.accuracy == accuracy;
  }

  @override
  int get hashCode => Object.hash(lat, lng, accuracy);
}

/// Represents AI suggestion for category and severity
class AISuggestion {
  /// Suggested category
  final Category category;

  /// Suggested severity
  final Severity severity;

  /// Confidence score between 0.0 and 1.0
  final double confidence;

  const AISuggestion({
    required this.category,
    required this.severity,
    required this.confidence,
  });

  /// Check if confidence is high enough to be considered reliable
  bool get isReliable => confidence >= 0.7;

  @override
  String toString() {
    return 'AISuggestion(category: ${category.name}, severity: ${severity.name}, confidence: ${confidence.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AISuggestion &&
        other.category == category &&
        other.severity == severity &&
        other.confidence == confidence;
  }

  @override
  int get hashCode => Object.hash(category, severity, confidence);
}