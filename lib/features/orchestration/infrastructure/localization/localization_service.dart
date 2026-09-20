/// Step 23 — Localization Service
///
/// Centralized localization for all orchestration user-facing strings.
/// Kurdish Sorani RTL first, English fallback.
///
/// Do not hardcode user-facing strings inside business logic.
/// All strings go through this service.

class LocalizationService {
  /// Kurdish Sorani translations (primary).
  static const Map<String, String> _ku = {
    // Status strings
    'status.completed': 'ئەنجامدرا',
    'status.cancelled': 'هەڵپەسێردرا',
    'status.understanding': 'تێگەیشتن…',
    'status.planning': 'پلاندانان…',
    'status.memory_lookup': 'بیرکردنەوە…',
    'status.tool_discovery': 'گەڕان بۆ ئامراز…',
    'status.security_checking': 'پشکنینی ئاسایش…',
    'status.permission_checking': 'پشکنینی ڕێگەپێدان…',
    'status.awaiting_confirmation': 'چاوەڕوانی پشتڕاستکردنەوە…',
    'status.executing': 'جێبەجێکردن…',
    'status.verifying': 'پشتڕاستکردنەوە…',
    'status.recovering': 'هەوڵی چارەسەرکردن…',
    'status.responding': 'وەڵامدانەوە…',
    'status.offline': 'بێ ئینتەرنێت',

    // Error strings
    'error.orchestration_failed': 'هەڵەی سیستەم. تکایە دووبارە هەوڵبدەرەوە.',
    'error.understanding_failed': 'ناتوانم داواکارییەکەت تێبگەم. تکایە دووبارە بیڵێوە.',
    'error.planning_failed': 'ناتوانم پلانێک دابنێم. تکایە دووبارە هەوڵبدەرەوە.',
    'error.memory_unavailable': 'بیرکردنەوە بەردەست نییە. بەبێ ئەویش بەردەوام دەبێت.',
    'error.tool_discovery_failed': 'هیچ ئامرازێک نەدۆزرایەوە بۆ ئەم داواکارییە.',
    'error.security_denied': 'ئاسایش ڕێگەی نەدا. کردارەکە ڕەتکرایەوە.',
    'error.permission_denied': 'ڕێگەپێدان ڕەتکرایەوە. تکایە ڕێگەپێدانەکان بپشکنە.',
    'error.confirmation_denied': 'پشتڕاستکردنەوە ڕەتکرایەوە. کردارەکە جێبەجێ ناکرێت.',
    'error.confirmation_deny_all': 'سیاسەتی ڕەتکردنەوە: هیچ کردارێک جێبەجێ ناکرێت.',
    'error.execution_failed': 'جێبەجێکردن سەرکەوتوو نەبوو. تکایە دووبارە هەوڵبدەرەوە.',
    'error.execution_denied': 'جێبەجێکردن ڕەتکرایەوە.',
    'error.recovery_failed': 'چارەسەرکردن سەرکەوتوو نەبوو.',
    'error.recovery_exhausted': 'هەموو هەوڵەکان بۆ چارەسەرکردن سەرکەوتوو نەبوون.',
    'error.offline_degraded': 'ئینتەرنێت بەردەست نییە. تەنها کردارە ناوخۆییەکان بەردەستن.',
    'error.offline_no_local_tools': 'لە دۆخی بێ ئینتەرنێتدا هیچ ئامرازێکی ناوخۆیی بەردەست نییە.',
    'error.security_unavailable': 'سیستەمی ئاسایش بەردەست نییە. کردارەکە ڕەتکرایەوە.',
    'error.permission_unavailable': 'سیستەمی ڕێگەپێدان بەردەست نییە. کردارەکە ڕەتکرایەوە.',
    'error.confirmation_unavailable': 'سیستەمی پشتڕاستکردنەوە بەردەست نییە. کردارەکە ڕەتکرایەوە.',
    'error.execution_unavailable': 'بزوێنەری جێبەجێکردن بەردەست نییە.',
    'error.recovery_unavailable': 'سیستەمی چارەسەرکردن بەردەست نییە.',

    // Confirmation prompts
    'confirmation.low_risk': 'ئەم کردارە کەم مەترسییە. دەتەوێت بەردەوام بیت؟',
    'confirmation.medium_risk': 'ئەم کردارە مامناوەندی مەترسییە. تکایە پشتڕاستی بکەرەوە.',
    'confirmation.high_risk': 'ئەم کردارە زۆر مەترسییە. دڵنیاییت لە بەردەوامبوون؟',
    'confirmation.deny_all': 'سیاسەتی ئاسایش ڕێگەی بە هیچ کردارێک نادات.',

    // Permission prompts
    'permission.required': 'ڕێگەپێدان پێویستە بۆ ئەم کردارە.',
    'permission.open_settings': 'تکایە ڕێگەپێدانەکان لە ڕێکخستنەکاندا چالاک بکە.',

    // Voice
    'voice.listening': 'گوێم لێتە…',
    'voice.speaking': 'دەقیتم…',
    'voice.unavailable': 'تێبینیکردنی دەنگ بەردەست نییە.',

    // Screen
    'screen.executing': 'کردارەکە لەسەر شاشە جێبەجێ دەکرێت…',
    'screen.unavailable': 'کۆنترۆڵی شاشە بەردەست نییە.',
  };

  /// English fallback translations.
  static const Map<String, String> _en = {
    'status.completed': 'Completed',
    'status.cancelled': 'Cancelled',
    'status.understanding': 'Understanding…',
    'status.planning': 'Planning…',
    'status.memory_lookup': 'Recalling…',
    'status.tool_discovery': 'Finding tools…',
    'status.security_checking': 'Checking security…',
    'status.permission_checking': 'Checking permissions…',
    'status.awaiting_confirmation': 'Awaiting confirmation…',
    'status.executing': 'Executing…',
    'status.verifying': 'Verifying…',
    'status.recovering': 'Recovering…',
    'status.responding': 'Responding…',
    'status.offline': 'Offline',
    'error.orchestration_failed': 'System error. Please try again.',
    'error.understanding_failed': 'I couldn\'t understand your request. Please try again.',
    'error.planning_failed': 'I couldn\'t create a plan. Please try again.',
    'error.memory_unavailable': 'Memory unavailable. Continuing without it.',
    'error.tool_discovery_failed': 'No tools found for this request.',
    'error.security_denied': 'Security denied. Action rejected.',
    'error.permission_denied': 'Permission denied. Please check your settings.',
    'error.confirmation_denied': 'Confirmation denied. Action will not execute.',
    'error.confirmation_deny_all': 'Deny-all policy: no actions will execute.',
    'error.execution_failed': 'Execution failed. Please try again.',
    'error.execution_denied': 'Execution denied.',
    'error.recovery_failed': 'Recovery failed.',
    'error.recovery_exhausted': 'All recovery attempts failed.',
    'error.offline_degraded': 'No internet. Only local actions are available.',
    'error.offline_no_local_tools': 'No local tools available while offline.',
    'error.security_unavailable': 'Security system unavailable. Action denied.',
    'error.permission_unavailable': 'Permission system unavailable. Action denied.',
    'error.confirmation_unavailable': 'Confirmation system unavailable. Action denied.',
    'error.execution_unavailable': 'Execution engine unavailable.',
    'error.recovery_unavailable': 'Recovery system unavailable.',
    'confirmation.low_risk': 'Low-risk action. Continue?',
    'confirmation.medium_risk': 'Medium-risk action. Please confirm.',
    'confirmation.high_risk': 'High-risk action. Are you sure?',
    'confirmation.deny_all': 'Security policy denies all actions.',
    'permission.required': 'Permission required for this action.',
    'permission.open_settings': 'Please enable permissions in settings.',
    'voice.listening': 'Listening…',
    'voice.speaking': 'Speaking…',
    'voice.unavailable': 'Voice recognition unavailable.',
    'screen.executing': 'Executing screen action…',
    'screen.unavailable': 'Screen control unavailable.',
  };

  /// Translate a key to the given locale.
  /// Kurdish Sorani first, English fallback.
  /// If neither has the key, returns the key itself.
  String translate(String key, String locale) {
    if (locale.startsWith('ku') || locale == 'ckb_IQ') {
      return _ku[key] ?? _en[key] ?? key;
    }
    return _en[key] ?? _ku[key] ?? key;
  }

  /// Get all keys for a locale.
  Map<String, String> allForLocale(String locale) {
    if (locale.startsWith('ku') || locale == 'ckb_IQ') {
      return Map.from(_ku)..addAll(_en); // ku overrides, en fills gaps
    }
    return Map.from(_en);
  }

  /// Whether a key exists for the given locale.
  bool hasKey(String key, String locale) {
    if (locale.startsWith('ku') || locale == 'ckb_IQ') {
      return _ku.containsKey(key) || _en.containsKey(key);
    }
    return _en.containsKey(key);
  }
}
