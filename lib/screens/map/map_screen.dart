import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/i18n.dart';
import '../../models/enums.dart';
import '../../models/report.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../widgets/severity_badge.dart';
import '../../widgets/status_badge.dart';
import '../my_reports/my_reports_screen.dart';

/// MapScreen - displays reports on an interactive OpenStreetMap with clustering
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  List<Report> _allReports = [];
  List<Report> _filteredReports = [];
  bool _loading = true;

  // In-memory filters
  Set<Category> _filterCategories = Category.all.toSet();
  Set<Severity> _filterSeverities = Severity.all.toSet();
  Set<Status> _filterStatuses = Status.all.toSet();
  DateTimeRange? _filterDateRange;

  // Defaults
  static final LatLng _defaultCenter = LatLng(3.1390, 101.6869); // Kuala Lumpur
  static const double _defaultZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
    _refresh();
  }

  void _setDefaultDateRange() {
    final now = DateTime.now();
    _filterDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final reports = await ApiService.fetchTickets();
    setState(() {
      _allReports = reports;
      _loading = false;
    });
    _applyFilters();
    // If we have filtered reports, fit; otherwise try device location
    if (_filteredReports.isNotEmpty) {
      debugPrint(
        '[map] _refresh: filtered=${_filteredReports.length}; scheduling fitBounds postFrame',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
    } else {
      debugPrint(
        '[map] _refresh: filtered=0; scheduling centerOnDeviceOrDefault postFrame',
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centerOnDeviceOrDefault(),
      );
    }
  }

  Future<void> _centerOnDeviceOrDefault() async {
    // Ensure the widget is still mounted before performing operations
    if (!mounted) return;

    try {
      final pos = await LocationService.getBestAvailablePosition();
      if (pos != null) {
        debugPrint(
          '[map] _centerOnDeviceOrDefault: moving to device location (${pos.latitude}, ${pos.longitude})',
        );
        try {
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            _defaultZoom,
          );
        } catch (e) {
          debugPrint('[map] Error moving to device location: $e');
        }
        return;
      }
    } catch (_) {}

    debugPrint(
      '[map] _centerOnDeviceOrDefault: moving to default center ($_defaultCenter) zoom=$_defaultZoom',
    );
    try {
      _mapController.move(_defaultCenter, _defaultZoom);
    } catch (e) {
      debugPrint('[map] Error moving to default center: $e');
    }
  }

  void _applyFilters() {
    final range = _filterDateRange;
    _filteredReports = _allReports.where((r) {
      if (!_filterCategories.contains(r.category)) return false;
      if (!_filterSeverities.contains(r.severity)) return false;
      if (!_filterStatuses.contains(r.status)) return false;

      if (range != null) {
        final created = DateTime.tryParse(r.createdAt);
        if (created == null) return false;
        // include the end day fully
        final endInclusive = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        if (created.isBefore(range.start) || created.isAfter(endInclusive))
          return false;
      }
      return true;
    }).toList();

    setState(() {});

    if (_filteredReports.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
    }
  }

  void _fitToBounds() {
    if (_filteredReports.isEmpty || !mounted) return;
    final points = _filteredReports
        .map((r) => LatLng(r.location.lat, r.location.lng))
        .toList();
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (e) {
      debugPrint('[map] Error fitting to bounds: $e');
    }
  }

  List<Marker> _buildMarkers() {
    return _filteredReports.map((r) {
      final latlng = LatLng(r.location.lat, r.location.lng);
      final severityColor = _getSeverityColor(r.severity);

      return Marker(
        point: latlng,
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () => _onMarkerTap(r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: severityColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getCategoryIcon(r.category),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Color _getSeverityColor(Severity severity) {
    switch (severity) {
      case Severity.high:
        return const Color(0xFFDC2626);
      case Severity.medium:
        return const Color(0xFFF59E0B);
      case Severity.low:
        return const Color(0xFF16A34A);
    }
  }

  IconData _getCategoryIcon(Category category) {
    switch (category) {
      case Category.pothole:
        return Icons.warning;
      case Category.streetlight:
        return Icons.lightbulb;
      case Category.signage:
        return Icons.traffic;
      case Category.trash:
        return Icons.delete;
      case Category.drainage:
        return Icons.water;
      case Category.other:
        return Icons.category;
    }
  }

  void _onMarkerTap(Report r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(r),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            I18n.t(r.category.key),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SeverityBadge(severity: r.severity, small: true),
                              const SizedBox(width: 8),
                              StatusBadge(status: r.status, small: true),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${I18n.t('label.location')}: ${r.location.lat.toStringAsFixed(6)}, ${r.location.lng.toStringAsFixed(6)}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${I18n.t('label.createdAt')}: ${r.createdAt.split('T').first}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop(); // close sheet
                        // Navigate to My Reports tab/screen (simplest)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyReportsScreen(),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              I18n.t('map.openedInMyReports').isNotEmpty
                                  ? I18n.t('map.openedInMyReports')
                                  : I18n.t('nav.myReports'),
                            ),
                          ),
                        );
                      },
                      child: Text(I18n.t('btn.viewDetails')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          _openExternalMap(r.location.lat, r.location.lng),
                      child: Text(I18n.t('btn.openMap')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(Report r) {
    final placeholder = Container(
      width: 120,
      height: 90,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.photo, color: Colors.grey.shade600),
    );

    // Prefer backend-provided image URL when available
    if (r.imageUrl != null && r.imageUrl!.isNotEmpty) {
      return Image.network(
        r.imageUrl!,
        width: 120,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    if (kIsWeb) {
      if (r.base64Photo != null && r.base64Photo!.isNotEmpty) {
        try {
          final bytes = base64Decode(r.base64Photo!);
          return Image.memory(bytes, width: 120, height: 90, fit: BoxFit.cover);
        } catch (_) {
          return placeholder;
        }
      }
      return placeholder;
    } else {
      if (r.photoPath != null && r.photoPath!.isNotEmpty) {
        final file = File(r.photoPath!);
        if (file.existsSync()) {
          return Image.file(file, width: 120, height: 90, fit: BoxFit.cover);
        }
      }
      return placeholder;
    }
  }

  Future<void> _openExternalMap(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(I18n.t('error.openMap'))));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(I18n.t('error.openMap'))));
    }
  }

  Future<void> _openFilterModal() async {
    // Use current filters as initial values
    final now = DateTime.now();
    Set<Category> selCategories = Set.from(_filterCategories);
    Set<Severity> selSeverities = Set.from(_filterSeverities);
    Set<Status> selStatuses = Set.from(_filterStatuses);
    DateTimeRange? selRange = _filterDateRange;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            I18n.t('btn.filter'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(I18n.t('filter.category')),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: Category.all.map((c) {
                          final selected = selCategories.contains(c);
                          return FilterChip(
                            label: Text(I18n.t(c.key)),
                            selected: selected,
                            onSelected: (v) {
                              setModalState(() {
                                if (v) {
                                  selCategories.add(c);
                                } else {
                                  selCategories.remove(c);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(I18n.t('filter.severity')),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: Severity.all.map((s) {
                          final selected = selSeverities.contains(s);
                          return FilterChip(
                            label: Text(I18n.t(s.key)),
                            selected: selected,
                            onSelected: (v) {
                              setModalState(() {
                                if (v) {
                                  selSeverities.add(s);
                                } else {
                                  selSeverities.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(I18n.t('filter.status')),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: Status.all.map((st) {
                          final selected = selStatuses.contains(st);
                          return FilterChip(
                            label: Text(I18n.t(st.key)),
                            selected: selected,
                            onSelected: (v) {
                              setModalState(() {
                                if (v) {
                                  selStatuses.add(st);
                                } else {
                                  selStatuses.remove(st);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(I18n.t('filter.dateRange')),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: now,
                                  initialDateRange:
                                      selRange ??
                                      DateTimeRange(
                                        start: now.subtract(
                                          const Duration(days: 30),
                                        ),
                                        end: now,
                                      ),
                                );
                                if (picked != null) {
                                  setModalState(() => selRange = picked);
                                }
                              },
                              child: Text(
                                selRange == null
                                    ? I18n.t('filter.dateRange')
                                    : '${selRange!.start.toLocal().toIso8601String().split('T').first} - ${selRange!.end.toLocal().toIso8601String().split('T').first}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                selCategories = Category.all.toSet();
                                selSeverities = Severity.all.toSet();
                                selStatuses = Status.all.toSet();
                                selRange = DateTimeRange(
                                  start: now.subtract(const Duration(days: 30)),
                                  end: now,
                                );
                              });
                            },
                            child: Text(I18n.t('btn.reset')),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // Apply
                              setState(() {
                                _filterCategories = selCategories;
                                _filterSeverities = selSeverities;
                                _filterStatuses = selStatuses;
                                _filterDateRange = selRange;
                              });
                              _applyFilters();
                              Navigator.pop(ctx);
                            },
                            child: Text(I18n.t('btn.apply')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('nav.map')),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterModal,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReports.isEmpty
          ? Center(child: Text(I18n.t('map.noReports')))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _filteredReports.isNotEmpty
                        ? LatLng(
                            _filteredReports.first.location.lat,
                            _filteredReports.first.location.lng,
                          )
                        : _defaultCenter,
                    initialZoom: _defaultZoom,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.citypulse',
                    ),
                    if (markers.isNotEmpty)
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 60,
                          size: const Size(48, 48),
                          markers: markers,
                          spiderfyCircleRadius: 80,
                          showPolygon: false,
                          disableClusteringAtZoom: 16,
                          builder: (context, markers) {
                            return Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF3B82F6),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                markers.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                          onClusterTap: (cluster) {
                            if (!mounted) return;
                            try {
                              final pts = cluster.markers
                                  .map((m) => m.point)
                                  .toList();
                              final bounds = LatLngBounds.fromPoints(pts);
                              _mapController.fitCamera(
                                CameraFit.bounds(
                                  bounds: bounds,
                                  padding: const EdgeInsets.all(60),
                                ),
                              );
                            } catch (e) {
                              debugPrint(
                                '[map] Error fitting cluster bounds: $e',
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
                // Enhanced Legend overlay
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              I18n.t('label.severity'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _enhancedLegendItem(
                          Severity.high,
                          '${I18n.t('severity.high')} Priority',
                        ),
                        const SizedBox(height: 8),
                        _enhancedLegendItem(
                          Severity.medium,
                          '${I18n.t('severity.medium')} Priority',
                        ),
                        const SizedBox(height: 8),
                        _enhancedLegendItem(
                          Severity.low,
                          '${I18n.t('severity.low')} Priority',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _enhancedLegendItem(Severity s, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _getSeverityColor(s),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Full screen report details used elsewhere in the app.
class MapReportDetails extends StatelessWidget {
  final Report report;
  const MapReportDetails({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(report.createdAt);
    return Scaffold(
      appBar: AppBar(title: Text(I18n.t('btn.details'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.imageUrl != null)
              Image.network(
                report.imageUrl!,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.photo, size: 64),
                ),
              )
            else if (kIsWeb && report.base64Photo != null)
              Image.memory(base64Decode(report.base64Photo!))
            else if (!kIsWeb && report.photoPath != null)
              Image.file(File(report.photoPath!))
            else
              Container(
                height: 180,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.photo, size: 64),
              ),
            const SizedBox(height: 12),
            Text(
              I18n.t(report.category.key),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SeverityBadge(severity: report.severity),
                const SizedBox(width: 8),
                StatusBadge(status: report.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${I18n.t('label.location')}: ${report.location.lat.toStringAsFixed(6)}, ${report.location.lng.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 8),
            Text(
              '${I18n.t('label.createdAt')}: ${created != null ? created.toLocal().toString() : report.createdAt}',
            ),
            const SizedBox(height: 8),
            if (report.notes != null)
              Text('${I18n.t('label.notes')}: ${report.notes}'),
          ],
        ),
      ),
    );
  }
}
