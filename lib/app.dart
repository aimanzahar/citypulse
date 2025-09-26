import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          localeResolutionCallback: (locale, supported) {
            debugPrint(
              '[i18n] localeResolution: device=$locale, supported=$supported',
            );
            if (locale == null) return supported.first;
            for (final s in supported) {
              if (s.languageCode == locale.languageCode) {
                return s;
              }
            }
            return supported.first;
          },
          builder: (context, child) {
            debugPrint(
              '[i18n] Building MaterialApp; locale=${localeProvider.locale}',
            );
            return child!;
          },
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.02),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIndex == 0
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, size: 24),
              ),
              label: I18n.t(_navLabels[0]),
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIndex == 1
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map, size: 24),
              ),
              label: I18n.t(_navLabels[1]),
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIndex == 2
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.list, size: 24),
              ),
              label: I18n.t(_navLabels[2]),
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIndex == 3
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings, size: 24),
              ),
              label: I18n.t(_navLabels[3]),
            ),
          ],
        ),
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
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title - Coming Soon!')),
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
  static const String _kUserModeKey = 'user_mode';

  String? _userMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(_kOnboardedKey) ?? false;
    final mode = prefs.getString(_kUserModeKey) ?? '';
    if (mounted) {
      setState(() {
        _onboarded = flag;
        _userMode = mode.isNotEmpty ? mode : null;
        _loading = false;
      });
    }
  }

  Future<void> _setGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserModeKey, 'guest');
    if (mounted) {
      setState(() {
        _userMode = 'guest';
      });
    }
  }

  Future<void> _setOnboarded({bool asGuest = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardedKey, true);
    if (asGuest) {
      await prefs.setString(_kUserModeKey, 'guest');
    }
    if (mounted) {
      setState(() {
        _onboarded = true;
        if (asGuest) _userMode = 'guest';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[i18n] StartRouter: hasMaterial=${Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) != null} locale=${Localizations.localeOf(context)}',
    );

    Widget screen;
    String screenKey;

    if (_loading) {
      screen = const Scaffold(body: Center(child: CircularProgressIndicator()));
      screenKey = 'loading';
    } else if (!_onboarded) {
      screen = WelcomeScreen(
        onContinue: () async {
          // Mark guest mode before continuing through onboarding flow
          await _setGuestMode();
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
          // Mark as onboarded and guest so next app start goes to main app
          await _setOnboarded(asGuest: true);
        },
      );
      screenKey = 'welcome';
    } else if (_userMode == 'guest') {
      // User is onboarded and in guest mode, take them to main app
      screen = const MainScreen();
      screenKey = 'main';
    } else {
      // User is onboarded but not in guest mode, show sign-in screen
      screen = const SignInScreen();
      screenKey = 'signin';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(screenKey), child: screen),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Enhanced header with better branding
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.build,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          I18n.t('app.name'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                        ),
                        Text(
                          'Civic Solutions', // TODO: Add to i18n as app.subtitle
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                // Enhanced main content with better visuals
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Hero icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        I18n.t('welcome.title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        I18n.t('welcome.subtitle'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withOpacity(0.8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Enhanced buttons
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    label: Text(
                      I18n.t('cta.continueGuest'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: onSignIn,
                    icon: const Icon(Icons.login, size: 20),
                    label: Text(
                      I18n.t('cta.signIn'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    I18n.t('cta.skip'),
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Enhanced onboarding flow with engaging civic messaging
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
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget _buildPage({
      required String title,
      required String subtitle,
      required String description,
      required IconData icon,
      required Color gradientStart,
      required Color gradientEnd,
    }) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced icon container with gradient
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: gradientStart.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface.withOpacity(0.8),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.build,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      I18n.t('onboarding.header'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Page view
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _buildPage(
                      title: I18n.t('onboarding.title1'),
                      subtitle: I18n.t('onboarding.subtitle1'),
                      description: I18n.t('onboarding.body1'),
                      icon: Icons.camera_alt,
                      gradientStart: const Color(0xFF22C55E),
                      gradientEnd: const Color(0xFF4ADE80),
                    ),
                    _buildPage(
                      title: I18n.t('onboarding.title2'),
                      subtitle: I18n.t('onboarding.subtitle2'),
                      description: I18n.t('onboarding.body2'),
                      icon: Icons.map,
                      gradientStart: const Color(0xFF2563EB),
                      gradientEnd: const Color(0xFF3B82F6),
                    ),
                    _buildPage(
                      title: I18n.t('onboarding.title3'),
                      subtitle: I18n.t('onboarding.subtitle3'),
                      description: I18n.t('onboarding.body3'),
                      icon: Icons.check_circle,
                      gradientStart: const Color(0xFFF97316),
                      gradientEnd: const Color(0xFFFB923C),
                    ),
                  ],
                ),
              ),
              // Enhanced bottom controls
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Page indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _index == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _index == index ? cs.primary : cs.outline,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            I18n.t('onboarding.skip'),
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _index < 2
                                ? I18n.t('onboarding.next')
                                : I18n.t('onboarding.getStarted'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(I18n.t('auth.comingSoon'))),
              ),
              icon: const Icon(Icons.apple),
              label: Text(I18n.t('auth.signInWithApple')),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.onSurface,
                foregroundColor: cs.surface,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(I18n.t('auth.comingSoon'))),
              ),
              icon: const Icon(Icons.g_mobiledata),
              label: Text(I18n.t('auth.signInWithGoogle')),
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarded_v1', true);
                await prefs.setString('user_mode', 'guest');
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                  );
                }
              },
              child: Text(I18n.t('cta.continueGuest')),
            ),
          ],
        ),
      ),
    );
  }
}
