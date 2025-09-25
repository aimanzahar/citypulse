import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Simple JSON-based internationalization service
class I18n {
  static Map<String, String> _localizedStrings = {};
  static const String _defaultLocale = 'en';
  static String _loadedLocale = _defaultLocale;

  /// Initialize the i18n system with the given locale
  static Future<void> init(Locale locale) async {
    _loadedLocale = locale.languageCode;
    await _loadLanguage(locale.languageCode);
  }

  /// Load language strings from JSON asset
  static Future<void> _loadLanguage(String languageCode) async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/lang/$languageCode.json',
      );
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
    } catch (e) {
      // Fallback to default locale if current locale fails
      // ignore: avoid_print
      print('Error loading language file for $languageCode: $e');
      if (languageCode != _defaultLocale) {
        _loadedLocale = _defaultLocale;
        await _loadLanguage(_defaultLocale);
      }
    }
  }

  /// Get translated string for the given key
  static String t(String key, [Map<String, String>? args]) {
    String? translation = _localizedStrings[key];

    if (translation == null) {
      // Fallback to key itself if translation not found
      // ignore: avoid_print
      print('Translation key not found: $key');
      return key;
    }

    // Replace placeholders if arguments provided
    if (args != null && args.isNotEmpty) {
      args.forEach((placeholder, value) {
        translation = translation!.replaceAll('{$placeholder}', value);
      });
    }

    return translation!;
  }

  /// Get the current locale code
  static String get currentLocale => _loadedLocale;

  /// Check if a translation key exists
  static bool hasKey(String key) {
    return _localizedStrings.containsKey(key);
  }

  /// Get all available translation keys
  static Set<String> get keys => _localizedStrings.keys.toSet();

  /// Get the number of loaded translations
  static int get translationCount => _localizedStrings.length;

  /// Clear loaded translations (useful for testing)
  static void clear() {
    _localizedStrings.clear();
    _loadedLocale = _defaultLocale;
  }
}