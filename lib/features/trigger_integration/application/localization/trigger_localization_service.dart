/// Step 24 — Trigger Localization Service
///
/// Provides localized messages for trigger states and results.
/// Kurdish Sorani RTL first (locale='ku').
/// FAIL-CLOSED: missing locale/translation → falls back to Kurdish Sorani.
/// FAIL-CLOSED: missing key → returns a deny-oriented message.

class TriggerLocalizationService {
  final String defaultLocale;

  TriggerLocalizationService({this.defaultLocale = 'ku'});

  /// Kurdish Sorani messages — the PRIMARY locale.
  static const Map<String, String> _kuMessages = {
    'trigger_type_unknown': 'جۆری تریگەر نەناسراوە — ڕێگەپێنەدراو',
    'trigger_type_not_authorizable': 'ئەم جۆرە تریگەرە ڕێگەپێنەدراوە',
    'authorization_denied': 'ڕێگەپێنەدراو — ڕەتکرایەوە',
    'authorization_unavailable': 'سیستەمی ڕێگەپێدان بەردەست نییە',
    'authorization_availability_error': 'هەڵە لە پشکنینی ڕێگەپێدان',
    'authorization_error': 'هەڵە لە ڕێگەپێدان',
    'trigger_type_not_permitted': 'ئەم جۆرە تریگەرە ڕێگەپێنەدراوە بەپێی سیاسەت',
    'policy_check_error': 'هەڵە لە پشکنینی سیاسەت',
    'routing_error': 'هەڵە لە ڕێکخستنی تریگەر',
    'fail_closed_deny': 'ڕێگەپێنەدراو — سیاسەتی داخراو',
    'engine_unavailable': 'ئەنجاینەری فلاتەر بەردەست نییە',
    'launch_failed': 'دەستپێکردن سەرنەکەوت',
    'service_unavailable': 'خزمەتگوزاری بەردەست نییە',
    'denied': 'ڕێگەپێنەدراو',
    'failed': 'سەرنەکەوت',
    'unavailable': 'بەردەست نییە',
    'launched': 'دەستپێکرا',
  };

  /// English messages — secondary fallback.
  static const Map<String, String> _enMessages = {
    'trigger_type_unknown': 'Unknown trigger type — denied',
    'trigger_type_not_authorizable': 'This trigger type is not authorizable',
    'authorization_denied': 'Authorization denied',
    'authorization_unavailable': 'Authorization system unavailable',
    'authorization_availability_error': 'Authorization availability check error',
    'authorization_error': 'Authorization error',
    'trigger_type_not_permitted': 'This trigger type is not permitted by policy',
    'policy_check_error': 'Policy check error',
    'routing_error': 'Trigger routing error',
    'fail_closed_deny': 'Denied — fail-closed policy',
    'engine_unavailable': 'Flutter engine unavailable',
    'launch_failed': 'Launch failed',
    'service_unavailable': 'Service unavailable',
    'denied': 'Denied',
    'failed': 'Failed',
    'unavailable': 'Unavailable',
    'launched': 'Launched',
  };

  /// Get a localized denied message.
  /// FAIL-CLOSED: unknown key → returns generic Kurdish deny message.
  String getDeniedMessage(String key, {String? locale}) {
    final loc = locale ?? defaultLocale;
    return _getMessage(key, loc);
  }

  /// Get a localized message for any key.
  /// FAIL-CLOSED: missing key → generic deny message.
  String getMessage(String key, {String? locale}) {
    final loc = locale ?? defaultLocale;
    return _getMessage(key, loc);
  }

  String _getMessage(String key, String locale) {
    // Kurdish Sorani first
    if (locale == 'ku' || locale.startsWith('ckb')) {
      return _kuMessages[key] ?? _kuMessages['fail_closed_deny']!;
    }

    // English fallback
    if (locale == 'en' || locale.startsWith('en')) {
      return _enMessages[key] ?? _enMessages['fail_closed_deny']!;
    }

    // FAIL-CLOSED: any other locale → Kurdish (primary)
    return _kuMessages[key] ?? _kuMessages['fail_closed_deny']!;
  }
}
