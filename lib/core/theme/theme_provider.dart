import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'app_colors_adaptive.dart';

/// Supported theme modes within AURA — now includes Natural.
enum AuraThemeMode {
  dark,
  light,
  natural,
  system;

  /// Maps to the [AuraThemeVariant] for theming, resolving system to dark by default.
  AuraThemeVariant toVariant() {
    switch (this) {
      case AuraThemeMode.dark:
        return AuraThemeVariant.dark;
      case AuraThemeMode.light:
        return AuraThemeVariant.light;
      case AuraThemeMode.natural:
        return AuraThemeVariant.natural;
      case AuraThemeMode.system:
        return AuraThemeVariant.dark;
    }
  }

  ThemeMode toThemeMode() {
    switch (this) {
      case AuraThemeMode.dark:
        return ThemeMode.dark;
      case AuraThemeMode.light:
        return ThemeMode.light;
      case AuraThemeMode.natural:
        // Natural is a light variant — use light mode for system resolution.
        return ThemeMode.light;
      case AuraThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// Persists and exposes the current [AuraThemeMode].
class ThemeNotifier extends StateNotifier<AuraThemeMode> {
  ThemeNotifier(this._prefs) : super(AuraThemeMode.dark) {
    _loadFromPrefs();
  }

  final SharedPreferences _prefs;

  void _loadFromPrefs() {
    final saved = _prefs.getString(AppConstants.themeKey);
    if (saved != null) {
      final mode = AuraThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (mode != null) {
        state = mode;
      }
    }
  }

  void setTheme(AuraThemeMode mode) {
    state = mode;
    _prefs.setString(AppConstants.themeKey, mode.name);
  }
}

/// Riverpod provider for theme mode.
final themeProvider = StateNotifierProvider<ThemeNotifier, AuraThemeMode>((ref) {
  throw UnimplementedError(
    'themeProvider must be overridden with SharedPreferences in main.dart',
  );
});

/// Resolves the [ThemeData] from the current [AuraThemeMode].
/// Located in app_providers.dart to avoid circular imports.
// final themeDataProvider = Provider<ThemeData>((ref) { ... });
