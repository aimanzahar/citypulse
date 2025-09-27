import 'package:flutter/material.dart';
import '../../services/storage.dart';
import '../../services/api_service.dart';
import '../../models/report.dart';
import '../../widgets/report_card.dart';
import '../map/map_screen.dart';
import '../../l10n/i18n.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<Report> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);

    try {
      // Try to fetch tickets from API and filter by this device's user id
      final userId = await ApiService.getUserId();
      final apiReports = await ApiService.fetchTickets();

      // Keep only reports that belong to this device/user
      final myApiReports = apiReports.where((r) => r.deviceId == userId).toList();

      // Also include any local reports stored that belong to this device
      final localReports = await StorageService.getReports();
      final myLocalReports = localReports.where((r) => r.deviceId == userId).toList();

      // Merge by id, prefer API version when available
      final Map<String, Report> merged = {};
      for (final r in myApiReports) merged[r.id] = r;
      for (final r in myLocalReports) {
        if (!merged.containsKey(r.id)) merged[r.id] = r;
      }

      final combined = merged.values.toList();

      setState(() {
        if (combined.isNotEmpty) {
          _reports = combined.reversed.toList(); // newest first
        } else {
          // Fallback: show local reports if no API-backed reports found for this user
          _reports = localReports.reversed.toList();
        }
        _loading = false;
      });
    } catch (e) {
      // Conservative fallback to local storage
      final reports = await StorageService.getReports();
      setState(() {
        _reports = reports.reversed.toList();
        _loading = false;
      });
    }
  }

  void _onViewReport(Report r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapReportDetails(report: r)),
    );
  }

  void _onDeleted() async {
    await _loadReports();
  }

  void _onUpdated(Report updated) async {
    await _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('nav.myReports')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(child: Text(I18n.t('map.noReports')))
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final r = _reports[index];
                      return ReportCard(
                        report: r,
                        onView: () => _onViewReport(r),
                        onDeleted: _onDeleted,
                        onUpdated: _onUpdated,
                      );
                    },
                  ),
                ),
    );
  }
}