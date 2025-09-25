import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeProvider manages ThemeMode and High-Contrast flag with persistence.
class ThemeProvider extends ChangeNotifier {
  static const _kThemeModeKey = 'ui.theme_mode'; // 'system' | 'light' | 'dark'
  static const _kHighContrastKey = 'ui.high_contrast'; // bool

  ThemeMode _mode = ThemeMode.system;
  bool _highContrast = false;

  ThemeMode get themeMode => _mode;
  bool get highContrast => _highContrast;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kThemeModeKey) ?? 'system';
    _mode = _decodeMode(modeStr);
    _highContrast = prefs.getBool(_kHighContrastKey) ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _encodeMode(mode));
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    if (_highContrast == value) return;
    _highContrast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrastKey, value);
    notifyListeners();
  }

  String _encodeMode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  ThemeMode _decodeMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}