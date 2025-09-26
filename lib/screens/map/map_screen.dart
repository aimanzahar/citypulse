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
import '../../services/storage.dart';
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
    _filterDateRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final reports = await StorageService.getReports();
    setState(() {
      _allReports = reports;
      _loading = false;
    });
    _applyFilters();
    // If we have filtered reports, fit; otherwise try device location
    if (_filteredReports.isNotEmpty) {
      debugPrint('[map] _refresh: filtered=${_filteredReports.length}; scheduling fitBounds postFrame');
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
    } else {
      debugPrint('[map] _refresh: filtered=0; scheduling centerOnDeviceOrDefault postFrame');
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnDeviceOrDefault());
    }
  }

  Future<void> _centerOnDeviceOrDefault() async {
    try {
      final pos = await LocationService.getBestAvailablePosition();
      if (pos != null) {
        debugPrint('[map] _centerOnDeviceOrDefault: moving to device location (${pos.latitude}, ${pos.longitude})');
        _mapController.move(LatLng(pos.latitude, pos.longitude), _defaultZoom);
        return;
      }
    } catch (_) {}
    debugPrint('[map] _centerOnDeviceOrDefault: moving to default center ($_defaultCenter) zoom=$_defaultZoom');
    _mapController.move(_defaultCenter, _defaultZoom);
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
        final endInclusive = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
        if (created.isBefore(range.start) || created.isAfter(endInclusive)) return false;
      }
      return true;
    }).toList();

    setState(() {});

    if (_filteredReports.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
    }
  }

  void _fitToBounds() {
    if (_filteredReports.isEmpty) return;
    final points = _filteredReports.map((r) => LatLng(r.location.lat, r.location.lng)).toList();
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (_) {
      // ignore
    }
  }

  List<Marker> _buildMarkers() {
    return _filteredReports.map((r) {
      final latlng = LatLng(r.location.lat, r.location.lng);
      return Marker(
        point: latlng,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _onMarkerTap(r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: r.severity.color, size: 36),
            ],
          ),
        ),
      );
    }).toList();
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
                          Text(I18n.t(r.category.key), style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Row(children: [
                            SeverityBadge(severity: r.severity, small: true),
                            const SizedBox(width: 8),
                            StatusBadge(status: r.status, small: true),
                          ]),
                          const SizedBox(height: 8),
                          Text('${I18n.t('label.location')}: ${r.location.lat.toStringAsFixed(6)}, ${r.location.lng.toStringAsFixed(6)}'),
                          const SizedBox(height: 4),
                          Text('${I18n.t('label.createdAt')}: ${r.createdAt.split('T').first}'),
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
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyReportsScreen()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(I18n.t('map.openedInMyReports') ?? I18n.t('nav.myReports'))),
                        );
                      },
                      child: Text(I18n.t('btn.viewDetails')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _openExternalMap(r.location.lat, r.location.lng),
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
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('error.openMap'))));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('error.openMap'))));
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
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(I18n.t('btn.filter'), style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: Text(I18n.t('filter.category'))),
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
                  Align(alignment: Alignment.centerLeft, child: Text(I18n.t('filter.severity'))),
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
                  Align(alignment: Alignment.centerLeft, child: Text(I18n.t('filter.status'))),
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
                  Align(alignment: Alignment.centerLeft, child: Text(I18n.t('filter.dateRange'))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: now,
                            initialDateRange: selRange ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
                          );
                          if (picked != null) {
                            setModalState(() => selRange = picked);
                          }
                        },
                        child: Text(selRange == null ? I18n.t('filter.dateRange') : '${selRange!.start.toLocal().toIso8601String().split('T').first} - ${selRange!.end.toLocal().toIso8601String().split('T').first}'),
                      ),
                    ),
                  ]),
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
                            selRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
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
                ]),
              ),
            ),
          );
        });
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
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _openFilterModal),
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
                            ? LatLng(_filteredReports.first.location.lat, _filteredReports.first.location.lng)
                            : _defaultCenter,
                        initialZoom: _defaultZoom,
                        minZoom: 3.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.citypulse',
                        ),
                        if (markers.isNotEmpty)
                          MarkerClusterLayerWidget(
                            options: MarkerClusterLayerOptions(
                              maxClusterRadius: 60,
                              size: const Size(40, 40),
                              markers: markers,
                              spiderfyCircleRadius: 80,
                              showPolygon: false,
                              disableClusteringAtZoom: 16,
                              builder: (context, markers) {
                                return Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    markers.length.toString(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                              onClusterTap: (cluster) {
                                try {
                                  final pts = cluster.markers.map((m) => m.point).toList();
                                  final bounds = LatLngBounds.fromPoints(pts);
                                  _mapController.fitCamera(
                                    CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
                                  );
                                } catch (_) {}
                              },
                            ),
                          ),
                      ],
                    ),
                    // Legend overlay
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _legendItem(Severity.high, I18n.t('severity.high')),
                              const SizedBox(width: 8),
                              _legendItem(Severity.medium, I18n.t('severity.medium')),
                              const SizedBox(width: 8),
                              _legendItem(Severity.low, I18n.t('severity.low')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _legendItem(Severity s, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (kIsWeb && report.base64Photo != null)
            Image.memory(base64Decode(report.base64Photo!))
          else if (!kIsWeb && report.photoPath != null)
            Image.file(File(report.photoPath!))
          else
            Container(height: 180, color: Colors.grey.shade200, alignment: Alignment.center, child: const Icon(Icons.photo, size: 64)),
          const SizedBox(height: 12),
          Text(I18n.t(report.category.key), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(children: [SeverityBadge(severity: report.severity), const SizedBox(width: 8), StatusBadge(status: report.status)]),
          const SizedBox(height: 12),
          Text('${I18n.t('label.location')}: ${report.location.lat.toStringAsFixed(6)}, ${report.location.lng.toStringAsFixed(6)}'),
          const SizedBox(height: 8),
          Text('${I18n.t('label.createdAt')}: ${created != null ? created.toLocal().toString() : report.createdAt}'),
          const SizedBox(height: 8),
          if (report.notes != null) Text('${I18n.t('label.notes')}: ${report.notes}'),
        ]),
      ),
    );
  }
}