import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/report.dart';
import '../l10n/i18n.dart';

/// Service for geocoding operations (converting addresses to coordinates and vice versa)
class GeocodingService {
  /// Nominatim API base URL (OpenStreetMap)
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// Search for locations by text query with timeout and better error handling
  static Future<List<LocationSearchResult>> searchLocations(
    String query, {
    int limit = 5,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        '$_nominatimBaseUrl/search?format=json&q=$encodedQuery&limit=$limit&addressdetails=1&dedupe=1', // Simplified parameters for faster response
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'CityPulse/1.0 (contact@citypulse.app)',
              'Accept': 'application/json',
              'Accept-Language': I18n.currentLocale,
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Filter out low-quality results
        final filteredData = data.where((item) {
          final importance = item['importance'] as num?;
          return importance == null ||
              importance > 0.1; // Filter out very low importance results
        }).toList();

        return filteredData
            .map((item) => LocationSearchResult.fromJson(item))
            .toList();
      } else {
        print('Geocoding search failed: ${response.statusCode}');
        return [];
      }
    } on TimeoutException catch (e) {
      // Let the caller handle timeout (UI may trigger a fallback)
      print('Error searching locations: $e');
      rethrow;
    } catch (e) {
      print('Error searching locations: $e');
      return [];
    }
  }

  /// Get address from coordinates (reverse geocoding) with timeout
  static Future<String?> getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    try {
      final url = Uri.parse(
        '$_nominatimBaseUrl/reverse?format=json&lat=$lat&lon=$lng&zoom=14',
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'CityPulse/1.0 (contact@citypulse.app)',
              'Accept': 'application/json',
              'Accept-Language': I18n.currentLocale,
            },
          )
          .timeout(
            const Duration(seconds: 2),
          ); // Shorter timeout for reverse geocoding

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _formatAddress(data);
      } else {
        print('Reverse geocoding failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  /// Format address from Nominatim response
  static String _formatAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;

    if (address == null) {
      return '${data['lat']}, ${data['lon']}';
    }

    final parts = <String>[];

    if (address['house_number'] != null) {
      parts.add(address['house_number']);
    }

    if (address['road'] != null) {
      parts.add(address['road']);
    }

    if (address['suburb'] != null) {
      parts.add(address['suburb']);
    } else if (address['neighbourhood'] != null) {
      parts.add(address['neighbourhood']);
    }

    if (address['city'] != null) {
      parts.add(address['city']);
    } else if (address['town'] != null) {
      parts.add(address['town']);
    } else if (address['village'] != null) {
      parts.add(address['village']);
    }

    if (address['state'] != null) {
      parts.add(address['state']);
    }

    if (address['country'] != null) {
      parts.add(address['country']);
    }

    return parts.isNotEmpty
        ? parts.join(', ')
        : '${data['lat']}, ${data['lon']}';
  }

  /// Get current location as a formatted address
  static Future<String?> getCurrentLocationAddress() async {
    try {
      // This would need the LocationService to be integrated
      // For now, return a placeholder
      return null;
    } catch (e) {
      print('Error getting current location address: $e');
      return null;
    }
  }

  /// Photon (Komoot) search fallback
  static Future<List<LocationSearchResult>> searchLocationsPhoton(
    String query, {
    int limit = 5,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final String lang = I18n.currentLocale;
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=$encodedQuery&limit=$limit&lang=$lang',
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'CityPulse/1.0 (contact@citypulse.app)',
              'Accept': 'application/json',
              'Accept-Language': lang,
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features =
            (data['features'] as List<dynamic>?) ?? [];
        return features
            .whereType<Map<String, dynamic>>()
            .map((f) => LocationSearchResult.fromPhotonFeature(f))
            .toList();
      } else {
        return [];
      }
    } on TimeoutException catch (e) {
      // propagate to let UI decide
      // ignore: avoid_print
      print('Photon search timeout: $e');
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('Photon search error: $e');
      return [];
    }
  }
}

/// Represents a location search result
class LocationSearchResult {
  final String displayName;
  final double lat;
  final double lng;
  final String? address;
  final String? city;
  final String? country;
  final String? type;

  LocationSearchResult({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.address,
    this.city,
    this.country,
    this.type,
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      displayName: json['display_name'] ?? '',
      lat: double.parse(json['lat'] ?? '0'),
      lng: double.parse(json['lon'] ?? '0'),
      address:
          json['address']?['road'] ??
          json['address']?['pedestrian'] ??
          json['address']?['path'],
      city:
          json['address']?['city'] ??
          json['address']?['town'] ??
          json['address']?['village'],
      country: json['address']?['country'],
      type: json['type'],
    );
  }

  /// Convert to LocationData
  LocationData toLocationData({double? accuracy}) {
    return LocationData(
      lat: lat,
      lng: lng,
      accuracy: accuracy ?? 10.0, // Default accuracy for searched locations
    );
  }

  @override
  String toString() {
    return 'LocationSearchResult(displayName: $displayName, lat: $lat, lng: $lng)';
  }

  /// Construct from a Photon feature
  factory LocationSearchResult.fromPhotonFeature(Map<String, dynamic> feature) {
    final Map<String, dynamic>? properties =
        feature['properties'] as Map<String, dynamic>?;
    final Map<String, dynamic>? geometry =
        feature['geometry'] as Map<String, dynamic>?;
    final List<dynamic>? coordinates = geometry != null
        ? geometry['coordinates'] as List<dynamic>?
        : null;

    final double lat = coordinates != null && coordinates.length >= 2
        ? (coordinates[1] as num).toDouble()
        : 0.0;
    final double lng = coordinates != null && coordinates.length >= 2
        ? (coordinates[0] as num).toDouble()
        : 0.0;

    final String? name = properties?['name'] as String?;
    final String? street =
        (properties?['street'] ?? properties?['road']) as String?;
    final String? houseNumber = properties?['housenumber'] as String?;
    final String? city =
        (properties?['city'] ??
                properties?['town'] ??
                properties?['village'] ??
                properties?['county'])
            as String?;
    final String? country = properties?['country'] as String?;

    final List<String> addressParts = [];
    if (street != null && street.isNotEmpty) addressParts.add(street);
    if (houseNumber != null && houseNumber.isNotEmpty)
      addressParts.add(houseNumber);
    final String address = addressParts.join(' ');

    final String display = [
      if (name != null && name.isNotEmpty) name,
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');

    return LocationSearchResult(
      displayName: display.isNotEmpty ? display : (name ?? ''),
      lat: lat,
      lng: lng,
      address: address.isNotEmpty ? address : null,
      city: city,
      country: country,
      type: properties?['osm_key'] as String?,
    );
  }
}
