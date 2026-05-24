import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeModeKey = 'appearance_theme_mode';
  static const String _legacyDarkKey = 'appearance_dark_enabled';
  static const String _legacyFollowSystemKey = 'appearance_follow_system';

  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

  Future<void> init() async {
    themeNotifier.value = await getSavedThemeMode();
  }

  Future<ThemeMode> getSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final rawMode = prefs.getString(_themeModeKey);

    if (rawMode != null) {
      return _themeModeFromStorage(rawMode);
    }

    final followSystem = prefs.getBool(_legacyFollowSystemKey) ?? true;
    if (followSystem) return ThemeMode.system;

    final isDark = prefs.getBool(_legacyDarkKey) ?? false;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_themeModeKey, _themeModeToStorage(mode));

    // Giữ lại 2 key cũ để các màn cũ chưa refactor vẫn đọc đúng trạng thái.
    await prefs.setBool(_legacyFollowSystemKey, mode == ThemeMode.system);
    await prefs.setBool(_legacyDarkKey, mode == ThemeMode.dark);

    themeNotifier.value = mode;
  }

  Future<void> updateDarkMode(bool isDark) async {
    await updateThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> updateFollowSystem(bool followSystem) async {
    if (followSystem) {
      await updateThemeMode(ThemeMode.system);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_legacyDarkKey) ?? false;
    await updateThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  String labelOf(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Theo hệ thống';
      case ThemeMode.light:
        return 'Sáng';
      case ThemeMode.dark:
        return 'Tối';
    }
  }

  String _themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  ThemeMode _themeModeFromStorage(String rawMode) {
    switch (rawMode) {
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
