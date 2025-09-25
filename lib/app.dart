import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/i18n.dart';
import 'l10n/locale_provider.dart';
import 'screens/report_flow/capture_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/my_reports/my_reports_screen.dart';
import 'screens/settings/settings_screen.dart';

class FixMateApp extends StatelessWidget {
  const FixMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: I18n.t('app.name'),
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('ms', 'MY'),
          ],
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CaptureScreen(),
    const MapScreen(),
    const MyReportsScreen(),
    const SettingsScreen(),
  ];

  final List<String> _navLabels = [
    'nav.report',
    'nav.map',
    'nav.myReports',
    'nav.settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.camera_alt),
            label: I18n.t(_navLabels[0]),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map),
            label: I18n.t(_navLabels[1]),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list),
            label: I18n.t(_navLabels[2]),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: I18n.t(_navLabels[3]),
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text('$title - Coming Soon!'),
      ),
    );
  }
}