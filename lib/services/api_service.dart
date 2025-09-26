import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/report.dart';
import '../models/enums.dart';

/// Service for communicating with the FixMate Backend API
class ApiService {
  // Configure this to match your backend URL
  // Use localhost for web/desktop, network IP for mobile/emulator
  static const String _baseUrl = 'http://192.168.100.59:8000/api';
  static const String _uploadsUrl = 'http://192.168.100.59:8000/static/uploads';

  // Create a user ID for this device if not exists
  static Future<String> _getOrCreateUserId() async {
    // For now, generate a UUID for this device
    // In a real app, this would be stored securely
    return const Uuid().v4();
  }

  /// Create a new user
  static Future<String> createUser({
    required String name,
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'] as String;
      } else {
        throw Exception('Failed to create user: ${response.body}');
      }
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  /// Submit a report to the backend
  static Future<String> submitReport({
    required double latitude,
    required double longitude,
    required String description,
    required List<int> imageBytes,
    required String imageName,
  }) async {
    try {
      final userId = await _getOrCreateUserId();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/report'),
      );
      request.fields['user_id'] = userId;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['description'] = description;

      // Add the image file
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: imageName),
      );

      final response = await request.send();

      if (response.statusCode == 201) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        return data['ticket_id'] as String;
      } else {
        final responseBody = await response.stream.bytesToString();
        throw Exception('Failed to submit report: $responseBody');
      }
    } catch (e) {
      print('Error submitting report: $e');
      rethrow;
    }
  }

  /// Get all tickets from the backend
  static Future<List<Report>> getReports() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/tickets'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => _convertApiTicketToReport(json)).toList();
      } else {
        throw Exception('Failed to get reports: ${response.body}');
      }
    } catch (e) {
      print('Error getting reports: $e');
      // Return empty list if API is not available (fallback to local storage)
      return [];
    }
  }

  /// Get a single ticket by ID
  static Future<Report?> getReportById(String ticketId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/tickets/$ticketId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _convertApiTicketToReport(data);
      } else {
        throw Exception('Failed to get report: ${response.body}');
      }
    } catch (e) {
      print('Error getting report: $e');
      return null;
    }
  }

  /// Update ticket status
  static Future<bool> updateReportStatus(String ticketId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/tickets/$ticketId?new_status=$status'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating report status: $e');
      return false;
    }
  }

  /// Get analytics data
  static Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/analytics'));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get analytics: ${response.body}');
      }
    } catch (e) {
      print('Error getting analytics: $e');
      return {};
    }
  }

  /// Convert API ticket response to Report model
  static Report _convertApiTicketToReport(Map<String, dynamic> data) {
    return Report(
      id: data['ticket_id'] ?? '',
      category: _normalizeCategory(data['category'] ?? ''),
      severity: _normalizeSeverity(data['severity'] ?? 'N/A'),
      status: _normalizeStatus(data['status'] ?? 'New'),
      photoPath: data['image_path'] != null
          ? '$_uploadsUrl/${data['image_path'].split('/').last}'
          : null,
      location: LocationData(
        lat: (data['latitude'] as num?)?.toDouble() ?? 0.0,
        lng: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      createdAt: data['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: data['updated_at'] ?? DateTime.now().toIso8601String(),
      deviceId: 'api-${data['ticket_id'] ?? ''}',
      notes: data['description'] as String?,
      source: 'api',
      aiSuggestion: AISuggestion(
        category: _normalizeCategory(data['category'] ?? ''),
        severity: _normalizeSeverity(data['severity'] ?? 'N/A'),
        confidence: 0.8, // Default confidence since we don't get this from API
      ),
    );
  }

  /// Normalize category names to match the app's expected format
  static Category _normalizeCategory(String category) {
    // Convert API categories to app categories
    switch (category.toLowerCase()) {
      case 'pothole':
        return Category.pothole;
      case 'streetlight':
      case 'broken_streetlight':
        return Category.streetlight;
      case 'garbage':
        return Category.trash;
      case 'signage':
        return Category.signage;
      case 'drainage':
        return Category.drainage;
      default:
        return Category.other;
    }
  }

  /// Normalize severity levels
  static Severity _normalizeSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Severity.high;
      case 'medium':
        return Severity.medium;
      case 'low':
        return Severity.low;
      default:
        return Severity.low; // Default to low if unknown
    }
  }

  /// Normalize status values
  static Status _normalizeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Status.submitted;
      case 'in progress':
      case 'in_progress':
        return Status.inProgress;
      case 'fixed':
        return Status.fixed;
      default:
        return Status.submitted;
    }
  }
}
