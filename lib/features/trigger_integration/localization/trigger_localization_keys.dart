/// Step 24 — Trigger Localization Keys
///
/// Centralized localization keys for the trigger integration feature.
/// Kurdish Sorani RTL first (locale='ku').
/// FAIL-CLOSED: missing key → deny-oriented Kurdish fallback.

class TriggerLocalizationKeys {
  // --- Denied messages ---
  static const String deniedTriggerTypeUnknown =
      'trigger_type_unknown';
  static const String deniedTriggerTypeNotAuthorizable =
      'trigger_type_not_authorizable';
  static const String deniedAuthorization =
      'authorization_denied';
  static const String deniedAuthorizationUnavailable =
      'authorization_unavailable';
  static const String deniedAuthorizationError =
      'authorization_error';
  static const String deniedTriggerTypeNotPermitted =
      'trigger_type_not_permitted';
  static const String deniedPolicyCheckError =
      'policy_check_error';
  static const String deniedRoutingError =
      'routing_error';
  static const String deniedFailClosed =
      'fail_closed_deny';

  // --- Failed messages ---
  static const String failedLaunch =
      'launch_failed';
  static const String failedOrchestration =
      'orchestration_adapter_error';

  // --- Unavailable messages ---
  static const String unavailableEngine =
      'engine_unavailable';
  static const String unavailableService =
      'service_unavailable';

  // --- Success messages ---
  static const String launchedSuccess =
      'launched';

  // --- UI labels (Kurdish Sorani RTL) ---
  static const String tileLabel = 'ئاورا';
  static const String tileLabelActive = 'ئاورا — چالاک';
  static const String tileLabelInactive = 'ئاورا — چاوەڕوان';
  static const String tileLabelUnavailable = 'ئاورا — بەردەست نییە';

  // --- STT/TTS locale identifiers ---
  static const String sttLocale = 'ckb_IQ';
  static const String ttsLocale = 'ku';
  static const String appLocale = 'ku';

  // --- Default user prompt (Kurdish Sorani) ---
  static const String defaultPrompt =
      'بەکارهێنەری ئاورا، تکایە یارمەتیم بدە';

  // --- Notification action labels ---
  static const String notificationActionReply =
      'وەڵام';
  static const String notificationActionListen =
      'گوێبگرە';

  // --- Permission rationale ---
  static const String permissionRationaleAudio =
      'بۆ کارپێکردنی ئاورا، پێویستیم بە دەستگەیشتن بە مایکرۆفۆنە';

  // --- Home long-press limitation ---
  static const String homeLongPressLimitation =
      'home_long_press_third_party_limitation';

  // Private constructor — static only class.
  TriggerLocalizationKeys._();
}
