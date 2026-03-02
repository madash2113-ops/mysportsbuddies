import 'package:flutter/material.dart';

/// Manages the app-wide theme (dark / light).
/// Singleton ChangeNotifier — add to MultiProvider in main.dart.
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService _instance = ThemeService._();
  factory ThemeService() => _instance;

  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode   => _mode;
  bool      get isDark => _mode == ThemeMode.dark;

  /// Toggle between dark and light.
  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  /// Set a specific mode.
  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
