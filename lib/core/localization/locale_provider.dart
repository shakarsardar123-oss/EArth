import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Supported locales in AURA.
enum AuraLocale {
  ku('ku', '', TextDirection.rtl),
  en('en', 'US', TextDirection.ltr);

  const AuraLocale(this.code, this.countryCode, this.textDirection);
  final String code;
  final String countryCode;
  final TextDirection textDirection;

  Locale toLocale() => countryCode.isEmpty ? Locale(code) : Locale(code, countryCode);
}

/// Manages and persists the selected locale.
class LocaleNotifier extends StateNotifier<AuraLocale> {
  LocaleNotifier(this._prefs) : super(AuraLocale.ku) {
    _loadFromPrefs();
  }

  final SharedPreferences _prefs;

  void _loadFromPrefs() {
    final saved = _prefs.getString(AppConstants.localeKey);
    if (saved != null) {
      final locale = AuraLocale.values.where((l) => l.code == saved).firstOrNull;
      if (locale != null) state = locale;
    }
  }

  void setLocale(AuraLocale locale) {
    state = locale;
    _prefs.setString(AppConstants.localeKey, locale.code);
  }
}

/// Riverpod provider for the current locale.
final localeProvider = StateNotifierProvider<LocaleNotifier, AuraLocale>((ref) {
  throw UnimplementedError(
    'localeProvider must be overridden with SharedPreferences in main.dart',
  );
});
