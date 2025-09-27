import 'dart:math';
import '../models/enums.dart';
import '../models/report.dart';

/// Service for generating deterministic AI suggestions for reports
class MockAIService {
  /// Generate a deterministic seed based on report parameters
  static int _generateSeed(
    String id,
    String createdAt,
    double lat,
    double lng,
    int? photoSizeBytes,
  ) {
    final combined = '$id$createdAt$lat$lng${photoSizeBytes ?? 0}';
    var hash = 0;
    for (var i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash) + combined.codeUnitAt(i);
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.abs();
  }

  /// Generate AI suggestion for a report
  static AISuggestion generateSuggestion({
    required String id,
    required String createdAt,
    required double lat,
    required double lng,
    int? photoSizeBytes,
  }) {
    // Always return Pothole with High severity as requested
    // Generate high confidence score (0.85 - 0.95) to make it look reliable
    final seed = _generateSeed(id, createdAt, lat, lng, photoSizeBytes);
    final random = Random(seed);
    final confidence = 0.85 + (random.nextDouble() * 0.1); // 0.85 - 0.95

    return AISuggestion(
      category: Category.pothole, // Always Pothole
      severity: Severity.high, // Always High severity
      confidence: confidence,
    );
  }

  /// Check if the AI suggestion is reliable enough to use
  static bool isSuggestionReliable(AISuggestion suggestion) {
    return suggestion.confidence >= 0.7;
  }

  /// Get confidence level description
  static String getConfidenceDescription(double confidence) {
    if (confidence >= 0.8) {
      return 'High confidence';
    } else if (confidence >= 0.7) {
      return 'Medium confidence';
    } else {
      return 'Low confidence';
    }
  }
}
