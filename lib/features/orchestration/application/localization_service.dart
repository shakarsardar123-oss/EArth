/// Step 23 — Application Localization Service
///
/// Facade wrapping the infrastructure LocalizationService.
/// Used by the application and presentation layers to get localized strings.
/// Kurdish Sorani RTL first (locale='ku'), English fallback.
///
/// This is the APPLICATION-level facade. The actual string tables
/// live in infrastructure/localization/localization_service.dart.

import '../infrastructure/localization/localization_service.dart' as infra;

class AppLocalizationService {
  final infra.LocalizationService _impl;
  String _currentLocale;

  AppLocalizationService({String initialLocale = 'ku'})
      : _impl = infra.LocalizationService(),
        _currentLocale = initialLocale;

  /// Current active locale.
  String get currentLocale => _currentLocale;

  /// Set locale. Kurdish Sorani first, English fallback.
  void setLocale(String locale) {
    _currentLocale = locale;
  }

  /// Translate a key using the current locale.
  String t(String key) => _impl.translate(key, _currentLocale);

  /// Translate a key using a specific locale.
  String translate(String key, String locale) =>
      _impl.translate(key, locale);

  /// Whether a key exists for the current locale.
  bool hasKey(String key) => _impl.hasKey(key, _currentLocale);

  /// Get all strings for the current locale.
  Map<String, String> allStrings() => _impl.allForLocale(_currentLocale);
}
