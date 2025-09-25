import 'dart:math';
import 'package:flutter/foundation.dart' hide Category;
import '../models/enums.dart';
import '../models/report.dart';

/// Service for generating deterministic AI suggestions for reports
class MockAIService {
  /// Generate a deterministic seed based on report parameters
  static int _generateSeed(String id, String createdAt, double lat, double lng, int? photoSizeBytes) {
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
    final seed = _generateSeed(id, createdAt, lat, lng, photoSizeBytes);
    final random = Random(seed);

    // Category selection with weighted probabilities
    final categoryWeights = {
      Category.pothole: 0.35,
      Category.trash: 0.25,
      Category.streetlight: 0.15,
      Category.signage: 0.10,
      Category.drainage: 0.10,
      Category.other: 0.05,
    };

    // Apply heuristics based on image dimensions (if available)
    final aspectRatio = photoSizeBytes != null ? (random.nextDouble() * 2) : 1.0;
    if (aspectRatio > 1.2) {
      // Wide image - likely signage
      categoryWeights[Category.signage] = categoryWeights[Category.signage]! * 2;
      categoryWeights[Category.pothole] = categoryWeights[Category.pothole]! * 0.5;
    }

    // Select category based on weights
    final categoryRand = random.nextDouble();
    double cumulative = 0.0;
    Category selectedCategory = Category.pothole;

    for (final entry in categoryWeights.entries) {
      cumulative += entry.value;
      if (categoryRand <= cumulative) {
        selectedCategory = entry.key;
        break;
      }
    }

    // Severity selection with weighted probabilities
    final severityWeights = {
      Severity.medium: 0.45,
      Severity.high: 0.30,
      Severity.low: 0.25,
    };

    // Apply location accuracy heuristic
    final accuracy = random.nextDouble() * 50; // Simulate accuracy 0-50m
    final isNight = random.nextBool(); // Simulate night time

    if (accuracy <= 10 && isNight) {
      // High accuracy at night - bump high severity
      severityWeights[Severity.high] = severityWeights[Severity.high]! * 1.5;
      severityWeights[Severity.medium] = severityWeights[Severity.medium]! * 0.8;
    }

    // Select severity based on weights
    final severityRand = random.nextDouble();
    cumulative = 0.0;
    Severity selectedSeverity = Severity.medium;

    for (final entry in severityWeights.entries) {
      cumulative += entry.value;
      if (severityRand <= cumulative) {
        selectedSeverity = entry.key;
        break;
      }
    }

    // Generate confidence score (0.6 - 0.9)
    final confidence = 0.6 + (random.nextDouble() * 0.3);

    return AISuggestion(
      category: selectedCategory,
      severity: selectedSeverity,
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