import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app locale and language switching
class LocaleProvider extends ChangeNotifier {
  static const String _languageKey = 'lang';
  static const String _defaultLanguage = 'en';

  Locale _locale = const Locale('en');
  late SharedPreferences _prefs;

  /// Get the current locale
  Locale get locale => _locale;

  /// Get the current language code
  String get languageCode => _locale.languageCode;

  /// Initialize the locale provider
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedLanguage = _prefs.getString(_languageKey) ?? _defaultLanguage;
    _locale = Locale(savedLanguage);
    notifyListeners();
  }

  /// Set the locale and persist the change
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    await _prefs.setString(_languageKey, locale.languageCode);
    notifyListeners();
  }

  /// Toggle between English and Bahasa Malaysia
  Future<void> toggleLanguage() async {
    final newLanguage = _locale.languageCode == 'en' ? 'ms' : 'en';
    await setLocale(Locale(newLanguage));
  }

  /// Set language to English
  Future<void> setEnglish() async {
    await setLocale(const Locale('en'));
  }

  /// Set language to Bahasa Malaysia
  Future<void> setMalay() async {
    await setLocale(const Locale('ms'));
  }

  /// Check if current language is English
  bool get isEnglish => _locale.languageCode == 'en';

  /// Check if current language is Bahasa Malaysia
  bool get isMalay => _locale.languageCode == 'ms';

  /// Get the display name for the current language
  String get currentLanguageDisplayName {
    switch (_locale.languageCode) {
      case 'en':
        return 'English';
      case 'ms':
        return 'Bahasa Malaysia';
      default:
        return 'English';
    }
  }

  /// Get the native display name for the current language
  String get currentLanguageNativeName {
    switch (_locale.languageCode) {
      case 'en':
        return 'English';
      case 'ms':
        return 'Bahasa Malaysia';
      default:
        return 'English';
    }
  }

  /// Get available locales
  List<Locale> get availableLocales => const [
        Locale('en'),
        Locale('ms'),
      ];

  /// Get available language codes
  List<String> get availableLanguageCodes => ['en', 'ms'];

  /// Clear saved language preference
  Future<void> clearSavedLanguage() async {
    await _prefs.remove(_languageKey);
    _locale = const Locale(_defaultLanguage);
    notifyListeners();
  }

  /// Reset to default language
  Future<void> resetToDefault() async {
    await setLocale(const Locale(_defaultLanguage));
  }
}