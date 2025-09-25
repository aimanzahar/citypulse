import 'package:flutter/material.dart';
import '../../services/storage.dart';
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
    setState(() {
      _loading = true;
    });
    final reports = await StorageService.getReports();
    setState(() {
      _reports = reports.reversed.toList(); // newest first
      _loading = false;
    });
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