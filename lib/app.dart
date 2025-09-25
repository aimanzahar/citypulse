import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/i18n.dart';
import 'l10n/locale_provider.dart';
import 'screens/report_flow/capture_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/my_reports/my_reports_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'theme/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixMateApp extends StatelessWidget {
  const FixMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: I18n.t('app.name'),
          theme: AppThemes.light(),
          darkTheme: AppThemes.dark(),
          themeMode: ThemeMode.system,
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('ms', 'MY'),
          ],
          home: const StartRouter(),
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

/// Router that decides whether to show onboarding or main app
class StartRouter extends StatefulWidget {
  const StartRouter({super.key});

  @override
  State<StartRouter> createState() => _StartRouterState();
}

class _StartRouterState extends State<StartRouter> {
  bool _loading = true;
  bool _onboarded = false;

  static const String _kOnboardedKey = 'onboarded_v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(_kOnboardedKey) ?? false;
    if (mounted) {
      setState(() {
        _onboarded = flag;
        _loading = false;
      });
    }
  }

  Future<void> _setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardedKey, true);
    if (mounted) {
      setState(() {
        _onboarded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_onboarded) return const MainScreen();
    return WelcomeScreen(
      onContinue: () async {
        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        );
        if (completed == true) {
          await _setOnboarded();
        }
      },
      onSignIn: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
        );
      },
      onSkip: () async {
        await _setOnboarded();
      },
    );
  }
}

/// Branded welcome screen (in-app splash handoff)
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onSignIn;
  final VoidCallback onSkip;

  const WelcomeScreen({
    super.key,
    required this.onContinue,
    required this.onSignIn,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primary,
                    child: const Icon(Icons.build, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(I18n.t('app.name'), style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const Spacer(),
              Text(
                I18n.t('welcome.title'),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                I18n.t('welcome.subtitle'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurface.withOpacity(0.75)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(I18n.t('cta.continueGuest')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login),
                  label: Text(I18n.t('cta.signIn')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSkip,
                child: Text(I18n.t('cta.skip')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-step onboarding flow with concise benefits
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pc = PageController();
  int _index = 0;

  void _next() {
    if (_index < 2) {
      _pc.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget page(String titleKey, String bodyKey, IconData icon) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 48, backgroundColor: cs.primary, child: Icon(icon, color: Colors.white, size: 40)),
            const SizedBox(height: 24),
            Text(I18n.t(titleKey), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(I18n.t(bodyKey), style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('onboarding.header')),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                page('onboarding.title1', 'onboarding.body1', Icons.flash_on),
                page('onboarding.title2', 'onboarding.body2', Icons.map),
                page('onboarding.title3', 'onboarding.body3', Icons.check_circle),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                TextButton(onPressed: () => Navigator.pop(context, true), child: Text(I18n.t('cta.skip'))),
                const Spacer(),
                ElevatedButton(
                  onPressed: _next,
                  child: Text(_index < 2 ? I18n.t('cta.next') : I18n.t('cta.getStarted')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sign-in placeholder with SSO buttons; supports continue as guest
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(I18n.t('auth.title'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('auth.comingSoon')))),
              icon: const Icon(Icons.apple),
              label: Text(I18n.t('auth.signInWithApple')),
              style: ElevatedButton.styleFrom(backgroundColor: cs.onSurface, foregroundColor: cs.surface),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('auth.comingSoon')))),
              icon: const Icon(Icons.g_mobiledata),
              label: Text(I18n.t('auth.signInWithGoogle')),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(I18n.t('cta.continueGuest')),
            ),
          ],
        ),
      ),
    );
  }
}