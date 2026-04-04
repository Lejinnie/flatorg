import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKeyThemeMode = 'theme_mode';
const _valueDark = 'dark';
const _valueLight = 'light';

/// Persists and exposes the user's preferred [ThemeMode].
///
/// Defaults to [ThemeMode.light] on first launch.
/// Persists the choice to [SharedPreferences] so it survives restarts.
class ThemeModeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Loads the persisted theme preference.  Must be awaited before the first
  /// [MaterialApp] build so the initial theme is correct.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKeyThemeMode);
    _mode = saved == _valueDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Toggles between light and dark mode and persists the new value.
  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyThemeMode, isDark ? _valueDark : _valueLight);
    notifyListeners();
  }
}
