import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/report.dart';
import '../models/enums.dart';

/// Service for communicating with the CityPulse Backend API
class ApiService {
  // Configure this to match your backend URL
  // Use localhost for web/desktop, network IP for mobile/emulator
  static const String BASE_URL = 'http://192.168.100.59:8000';
  static const String _baseUrl = '$BASE_URL/api';
  static const String _uploadsUrl = '$BASE_URL/static/uploads';

  // Create a user ID for this device if not exists (persisted)
  static Future<String> _getOrCreateUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'fixmate_user_id';
      final existing = prefs.getString(key);
      if (existing != null && existing.isNotEmpty) return existing;
      final newId = Uuid().v4();
      await prefs.setString(key, newId);
      return newId;
    } catch (e) {
      // If SharedPreferences fails for any reason, fallback to an in-memory UUID
      return Uuid().v4();
    }
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

  /// Get or create the current device / user id used when submitting reports
  static Future<String> getUserId() => _getOrCreateUserId();

  /// Submit a report to the backend
  static Future<String> submitReport({
    required double latitude,
    required double longitude,
    required String description,
    required List<int> imageBytes,
    required String imageName,
    String? userName,
    String? address,
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
      if (userName != null && userName.isNotEmpty)
        request.fields['user_name'] = userName;
      if (address != null && address.isNotEmpty)
        request.fields['address'] = address;

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

  /// Preferred API name for fetching tickets (alias for getReports)
  static Future<List<Report>> fetchTickets() => getReports();

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

  /// Delete a ticket by ID
  static Future<bool> deleteTicket(String ticketId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/tickets/$ticketId'),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        print(
          'Failed to delete ticket: ${response.statusCode} ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('Error deleting ticket: $e');
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
    final id = (data['id'] ?? data['ticket_id'] ?? '').toString();
    final imageUrl =
        (data['image_url'] as String?) ??
        (data['image_path'] != null
            ? '$_uploadsUrl/${(data['image_path'] as String).split('/').last}'
            : null);

    return Report(
      id: id,
      category: _normalizeCategory(data['category'] ?? ''),
      severity: _normalizeSeverity(data['severity'] ?? 'N/A'),
      status: _normalizeStatus(data['status'] ?? 'New'),
      // For API-provided tickets prefer imageUrl; photoPath is for local files
      photoPath: null,
      imageUrl: imageUrl,
      location: LocationData(
        lat: (data['latitude'] as num?)?.toDouble() ?? 0.0,
        lng: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      createdAt:
          (data['created_at'] ??
                  data['createdAt'] ??
                  DateTime.now().toIso8601String())
              as String,
      updatedAt:
          (data['updated_at'] ??
                  data['updatedAt'] ??
                  DateTime.now().toIso8601String())
              as String,
      deviceId: data['user_id'] != null
          ? data['user_id'].toString()
          : 'api-$id',
      notes: data['description'] as String?,
      address: data['address'] as String?,
      submittedBy: data['user_name'] as String?,
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
