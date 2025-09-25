import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/i18n.dart';
import '../../l10n/locale_provider.dart';
import '../../services/storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StorageStats? _stats;
  bool _loadingStats = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loadingStats = true;
    });
    final stats = await StorageService.getStorageStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    }
  }

  Future<void> _confirmAndClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('confirm.clearData.title')),
        content: Text(I18n.t('confirm.clearData.message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t('btn.no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t('btn.yes'))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _clearing = true;
      });
      final ok = await StorageService.clearAllReports();
      setState(() {
        _clearing = false;
      });
      if (ok) {
        await _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('toast.storageCleared'))));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear data')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isEnglish = localeProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('nav.settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(I18n.t('settings.language')),
            subtitle: Text(isEnglish ? I18n.t('lang.en') : I18n.t('lang.ms')),
            trailing: Switch(
              value: isEnglish,
              onChanged: (v) async {
                // toggle language and reload translations
                if (v) {
                  await localeProvider.setEnglish();
                } else {
                  await localeProvider.setMalay();
                }
                await I18n.init(localeProvider.locale);
                // Force rebuild
                setState(() {});
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(I18n.t('settings.theme')),
            subtitle: Text(I18n.t('settings.theme.light')),
            trailing: const Icon(Icons.light_mode),
            enabled: false,
          ),
          const Divider(),
          ListTile(
            title: Text(I18n.t('settings.diagnostics')),
            subtitle: _loadingStats
                ? const Text('Loading...')
                : Text('${I18n.t('toast.reportSaved')}: ${_stats?.reportCount ?? 0} • ${_stats?.formattedPhotoSize ?? "0 B"}'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _clearing ? null : () => _confirmAndClearAll(context),
            icon: const Icon(Icons.delete_forever),
            label: _clearing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(I18n.t('btn.clearAll')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
          const SizedBox(height: 16),
          Text('App', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            title: Text(I18n.t('app.name')),
            subtitle: Text('v1.0.0'),
          ),
        ],
      ),
    );
  }
}