/// Step 24 — Method Channel Constants
///
/// Platform channel for Step 24 trigger integration.
/// Namespace: com.aura.assistant/trigger_integration
/// MUST NOT duplicate Step 15's MethodChannel — bridge to Step 15
/// where operations overlap (e.g., assistant role, security).

class TriggerMethodChannelConstants {
  /// Dedicated MethodChannel for Step 24.
  static const String channelName = 'com.aura.assistant/trigger_integration';

  // --- Method names (Android → Flutter) ---

  /// Quick Settings Tile triggered.
  static const String quickSettingsTrigger = 'quickSettingsTrigger';

  /// Assistant long-press triggered (via Step 15 assistant role bridge).
  static const String assistantLongPressTrigger =
      'assistantLongPressTrigger';

  /// Home long-press triggered (via Step 15 assistant role bridge).
  static const String homeLongPressTrigger = 'homeLongPressTrigger';

  /// Notification action triggered.
  static const String notificationActionTrigger = 'notificationActionTrigger';

  /// In-app trigger.
  static const String inAppTrigger = 'inAppTrigger';

  // --- Method names (Flutter → Android) ---

  /// Request to update Quick Settings Tile state.
  static const String updateTileState = 'updateTileState';

  /// Check if Flutter engine is available.
  static const String isEngineAvailable = 'isEngineAvailable';

  /// Notify Android side that trigger processing is complete.
  static const String triggerProcessingComplete =
      'triggerProcessingComplete';

  // --- Tile state values ---

  /// Tile is active (AURA is listening).
  static const String tileStateActive = 'active';

  /// Tile is inactive (idle).
  static const String tileStateInactive = 'inactive';

  /// Tile is unavailable (engine not running).
  static const String tileStateUnavailable = 'unavailable';

  // --- Argument keys ---

  static const String argRequestId = 'requestId';
  static const String argTriggerType = 'triggerType';
  static const String argSource = 'source';
  static const String argTextPayload = 'textPayload';
  static const String argIsVoiceInput = 'isVoiceInput';
  static const String argLocale = 'locale';
  static const String argMetadata = 'metadata';
  static const String argTileState = 'tileState';
  static const String argResultCode = 'resultCode';
  static const String argErrorMessage = 'errorMessage';
}
