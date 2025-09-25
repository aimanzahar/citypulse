import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/report.dart';

/// Service for handling location operations and permissions
class LocationService {
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('Error checking location service: $e');
      return false;
    }
  }

  /// Check location permissions
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      print('Error checking location permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Request location permissions
  static Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      print('Error requesting location permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Get current position with high accuracy
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      // Check permissions
      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Get current position with best available accuracy
  static Future<Position?> getBestAvailablePosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      // Check permissions
      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return null;
      }

      // Try high accuracy first, fallback to medium if it takes too long
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        print('High accuracy failed, trying medium accuracy: $e');
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      }
    } catch (e) {
      print('Error getting best available position: $e');
      return null;
    }
  }

  /// Convert Position to LocationData
  static LocationData positionToLocationData(Position position) {
    return LocationData(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
    );
  }

  /// Get location accuracy description
  static String getAccuracyDescription(double? accuracy) {
    if (accuracy == null) return 'Unknown';

    if (accuracy <= 3) {
      return 'Very High';
    } else if (accuracy <= 10) {
      return 'High';
    } else if (accuracy <= 50) {
      return 'Medium';
    } else if (accuracy <= 100) {
      return 'Low';
    } else {
      return 'Very Low';
    }
  }

  /// Check if location accuracy is good enough for reporting
  static bool isAccuracyGoodForReporting(double? accuracy) {
    if (accuracy == null) return false;
    return accuracy <= 50; // Within 50 meters is acceptable
  }

  /// Get user-friendly location permission status message
  static String getPermissionStatusMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return 'Location permission denied. Please enable location access to attach GPS coordinates to your reports.';
      case LocationPermission.deniedForever:
        return 'Location permission permanently denied. Please enable location access in your device settings to use this feature.';
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return 'Location permission granted.';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine location permission status.';
    }
  }

  /// Open device location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print('Error opening location settings: $e');
      return false;
    }
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(LocationData point1, LocationData point2) {
    return Geolocator.distanceBetween(
      point1.lat,
      point1.lng,
      point2.lat,
      point2.lng,
    );
  }

  /// Get address from coordinates (placeholder - would need geocoding service)
  static Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    // This is a placeholder implementation
    // In a real app, you would use a geocoding service like Google Maps API
    // or OpenStreetMap Nominatim API
    return null;
  }

  /// Validate location data
  static bool isValidLocation(LocationData location) {
    final acc = location.accuracy;
    return location.lat >= -90 &&
        location.lat <= 90 &&
        location.lng >= -180 &&
        location.lng <= 180 &&
        acc != null &&
        acc >= 0;
  }
}