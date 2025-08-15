// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kThemePreference = 'theme_preference';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default to system

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Get the stored integer, default to ThemeMode.system.index if not found
    int preferredThemeIndex =
        prefs.getInt(kThemePreference) ?? ThemeMode.system.index;
    _themeMode =
        ThemeMode.values[preferredThemeIndex.clamp(
          0,
          ThemeMode.values.length - 1,
        )];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return; // No change

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kThemePreference, mode.index);
  }

  // Helper to cycle through themes
  void cycleTheme() {
    if (_themeMode == ThemeMode.system) {
      setThemeMode(ThemeMode.light);
    } else if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      // ThemeMode.dark
      setThemeMode(ThemeMode.system);
    }
  }

  IconData get themeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.wb_sunny_outlined;
      case ThemeMode.dark:
        return Icons.nightlight_round_outlined;
      case ThemeMode.system:
      default:
        return Icons.settings_brightness_outlined;
    }
  }

  String get themeTooltip {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Switch to Dark Mode';
      case ThemeMode.dark:
        return 'Switch to System Default';
      case ThemeMode.system:
      default:
        return 'Switch to Light Mode';
    }
  }
}
