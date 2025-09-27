import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../l10n/i18n.dart';
import '../../models/report.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LocationData? initialLocation;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LocationData? _selectedLocation;
  String? _selectedAddress;
  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingLocation = false;
  bool _isMapLoading = true;
  bool _isGettingAddress = false;

  // Search optimization
  Timer? _searchDebounceTimer;
  final Map<String, List<LocationSearchResult>> _searchCache = {};
  static const Duration _searchDebounceDuration = Duration(
    milliseconds: 1200,
  ); // Increased debounce to prevent multiple calls

  // Default center (Kuala Lumpur, Malaysia)
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;

    // Set up timeouts first (before map operations)
    _setupTimeouts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _reverseGeocodeTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;

    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    // Check cache first
    if (_searchCache.containsKey(query)) {
      if (mounted) {
        setState(() {
          _searchResults = _searchCache[query]!;
          _isSearching = false;
        });
      }
      return;
    }

    // Debounce search requests
    _searchDebounceTimer = Timer(_searchDebounceDuration, () async {
      if (mounted) {
        await _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await GeocodingService.searchLocations(query);

      // Cache only non-empty results to avoid sticky empty cache on transient failures
      if (results.isNotEmpty) {
        _searchCache[query] = results;
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Geocoding search failed: $e, trying fallback...');

      // Try Photon fallback first, then a simplified Nominatim search
      try {
        final photonResults = await GeocodingService.searchLocationsPhoton(
          query,
        );
        if (photonResults.isNotEmpty) {
          _searchCache[query] = photonResults;
          if (mounted) {
            setState(() {
              _searchResults = photonResults;
              _isSearching = false;
            });
          }
          return;
        }

        final fallbackResults = await _performFallbackSearch(query);
        if (fallbackResults.isNotEmpty) {
          _searchCache[query] = fallbackResults;
        }

        if (mounted) {
          setState(() {
            _searchResults = fallbackResults;
            _isSearching = false;
          });
        }
      } catch (fallbackError) {
        print('Fallback search also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
        }
      }
    }
  }

  Future<List<LocationSearchResult>> _performFallbackSearch(
    String query,
  ) async {
    // Simplified search with basic parameters
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=3&addressdetails=0',
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
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => LocationSearchResult.fromJson(item)).toList();
    } else {
      throw Exception('Fallback search failed');
    }
  }

  Future<void> _useCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final locationData = LocationService.positionToLocationData(position);
        if (mounted) {
          setState(() {
            _selectedLocation = locationData;
          });
        }

        // Move map to current location (only if map is ready)
        try {
          _mapController.move(LatLng(locationData.lat, locationData.lng), 16.0);
        } catch (e) {
          print('Error moving map to current location: $e');
        }

        // Get address for current location
        final address = await GeocodingService.getAddressFromCoordinates(
          locationData.lat,
          locationData.lng,
        );
        if (mounted) {
          setState(() {
            _selectedAddress = address;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get current location')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Timer? _reverseGeocodeTimer;

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedLocation = LocationData(
        lat: point.latitude,
        lng: point.longitude,
        accuracy: 10.0, // Default accuracy for manual selection
      );
    });

    // Debounce reverse geocoding requests
    _reverseGeocodeTimer?.cancel();
    _reverseGeocodeTimer = Timer(const Duration(milliseconds: 500), () {
      _getAddressForLocation(point.latitude, point.longitude);
    });
  }

  Future<void> _getAddressForLocation(double lat, double lng) async {
    if (!mounted) return;

    setState(() {
      _isGettingAddress = true;
    });

    try {
      final address = await GeocodingService.getAddressFromCoordinates(
        lat,
        lng,
      );
      if (mounted) {
        setState(() {
          _selectedAddress = address;
          _isGettingAddress = false;
        });
      }
    } catch (e) {
      print('Reverse geocoding failed: $e, trying fallback...');

      // Try a simpler reverse geocoding approach
      try {
        final fallbackAddress = await _performFallbackReverseGeocoding(
          lat,
          lng,
        );
        if (mounted) {
          setState(() {
            _selectedAddress = fallbackAddress;
            _isGettingAddress = false;
          });
        }
      } catch (fallbackError) {
        print('Fallback reverse geocoding also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _isGettingAddress = false;
          });
        }
      }
    }
  }

  Future<String?> _performFallbackReverseGeocoding(
    double lat,
    double lng,
  ) async {
    // Simplified reverse geocoding with basic parameters
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=14',
    );

    final response = await http
        .get(
          url,
          headers: {'User-Agent': 'CityPulse/1.0 (contact@citypulse.app)'},
        )
        .timeout(const Duration(seconds: 2));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _formatSimpleAddress(data);
    } else {
      throw Exception('Fallback reverse geocoding failed');
    }
  }

  String _formatSimpleAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;

    if (address == null) {
      return '${data['lat']}, ${data['lon']}';
    }

    final parts = <String>[];

    if (address['road'] != null) {
      parts.add(address['road']);
    }

    if (address['city'] != null) {
      parts.add(address['city']);
    } else if (address['town'] != null) {
      parts.add(address['town']);
    }

    if (address['country'] != null) {
      parts.add(address['country']);
    }

    return parts.isNotEmpty
        ? parts.join(', ')
        : '${data['lat']}, ${data['lon']}';
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    _searchDebounceTimer?.cancel();
  }

  void _setupTimeouts() {
    // Set multiple timeouts to ensure loading screen never stays forever
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _isMapLoading) {
        print('Map loading timeout 800ms - still loading');
        setState(() {
          _isMapLoading = false;
        });
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isMapLoading) {
        print('Map loading timeout 2s - still loading');
        setState(() {
          _isMapLoading = false;
        });
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isMapLoading) {
        print('Map loading timeout 4s - still loading');
        setState(() {
          _isMapLoading = false;
        });
      }
    });

    // Final failsafe - absolutely must hide loading screen
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _isMapLoading) {
        print('FINAL FAILSAFE: Force hiding loading screen after 6s');
        setState(() {
          _isMapLoading = false;
        });
      }
    });
  }

  void _checkMapReady() {
    if (!mounted) return;

    // Simple check - if map controller has a position, consider it ready
    try {
      final center = _mapController.camera.center;
      print('Map center check: $center, loading: $_isMapLoading');
      if (_isMapLoading) {
        print('Map appears ready, hiding loading screen');
        setState(() {
          _isMapLoading = false;
        });
      }
    } catch (e) {
      print('Error checking map readiness: $e');
      // If we can't get center, the map might not be ready yet, but let's be more aggressive
      if (_isMapLoading) {
        print('Force hiding loading screen due to error');
        setState(() {
          _isMapLoading = false;
        });
      }
    }
  }

  void _initializeMap() {
    // This should be called after the map widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Center map on initial location or default location
      if (_selectedLocation != null) {
        try {
          _mapController.move(
            LatLng(_selectedLocation!.lat, _selectedLocation!.lng),
            16.0,
          );
          print('Map centered on initial location');
        } catch (e) {
          print('Error moving map to initial location: $e');
          // If map controller fails, still try to hide loading screen
          if (_isMapLoading) {
            setState(() {
              _isMapLoading = false;
            });
          }
        }
      }

      // Additional check after widgets are built
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isMapLoading) {
          print('Post-frame callback check - map still loading');
          _checkMapReady();
        }
      });
    });
  }

  void _selectSearchResult(LocationSearchResult result) {
    setState(() {
      _selectedLocation = result.toLocationData();
      _selectedAddress = result.displayName;
      _searchResults = [];
      _searchController.clear();
    });

    // Move map to selected location
    _mapController.move(LatLng(result.lat, result.lng), 16.0);
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(
        context,
      ).pop({'location': _selectedLocation, 'address': _selectedAddress});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          I18n.t('map.selectLocation'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        actions: [
          TextButton(
            onPressed: _confirmSelection,
            child: Text(
              I18n.t('btn.ok'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map with loading state
          _isMapLoading
              ? Container(
                  color: cs.surface.withOpacity(0.9),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          I18n.t('map.loadingMap'),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: cs.onSurface),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            print('User manually dismissed loading screen');
                            setState(() {
                              _isMapLoading = false;
                            });
                          },
                          child: Text(
                            I18n.t('map.continueAnyway'),
                            style: TextStyle(color: cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultCenter,
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) => _onMapTap(point),
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    onMapReady: () {
                      print('Map is ready, initializing...');
                      _initializeMap();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.citypulse',
                      // Add retina mode for better quality on high DPI devices
                      retinaMode: true,
                      // Add error handling for tile loading
                      errorTileCallback: (tile, error, stackTrace) {
                        print(
                          'Tile loading error: $error for tile $tile, stackTrace: $stackTrace',
                        );
                        // Return a transparent tile instead of showing error
                        return null;
                      },
                      // Fallback tile server
                      fallbackUrl:
                          'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    // Current location marker (if available)
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _selectedLocation!.lat,
                              _selectedLocation!.lng,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search input
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: I18n.t('map.searchHint'),
                        prefixIcon: Icon(
                          Icons.search,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSearching)
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(right: 8),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: cs.onSurface.withOpacity(0.6),
                                  size: 20,
                                ),
                                onPressed: _clearSearch,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            IconButton(
                              icon: Icon(Icons.my_location, color: cs.primary),
                              onPressed: _isLoadingLocation
                                  ? null
                                  : _useCurrentLocation,
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: cs.surface,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),

                  // Search results
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                            ),
                            title: Text(
                              result.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [result.city, result.country]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(result),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Selected location info
          if (_selectedLocation != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('map.selectedLocation'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isGettingAddress
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                I18n.t('map.gettingAddress'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: cs.onSurface.withOpacity(0.7),
                                    ),
                              ),
                            ],
                          )
                        : Text(
                            _selectedAddress ??
                                '${_selectedLocation!.lat.toStringAsFixed(6)}, ${_selectedLocation!.lng.toStringAsFixed(6)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurface),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    if (_selectedLocation!.accuracy != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Accuracy: ${_selectedLocation!.accuracy!.toStringAsFixed(1)}m',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Bottom action button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _confirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                I18n.t('btn.useThisLocation'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
