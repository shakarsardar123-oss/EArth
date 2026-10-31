/// tool_category.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Enumerates the categories of tools the agent can discover and execute.
/// Each tool belongs to exactly one category, which determines its
/// default risk level, confirmation policy, and permission requirements.
///
/// FAIL CLOSED: unknown category → highest risk.
library;

/// Categories of tools available in the AURA Assistant.
///
/// Categories drive:
///   - Default confirmation policy (system/communication → always)
///   - Default risk level (system → critical, voice → low, etc.)
///   - Permission requirements per category
///   - Discovery grouping in the Tool Discovery API
enum ToolCategory {
  /// Voice input/output tools (speech recognition, TTS, wake-word).
  voice,

  /// Screen interaction tools (UI automation, screen reading).
  screen,

  /// Vision / camera tools (image capture, OCR, barcode scanning).
  vision,

  /// Device hardware tools (sensors, Bluetooth, NFC).
  device,

  /// Semantic memory tools (remember, recall, search, forget, update).
  memory,

  /// Assistant orchestration tools (invoke, schedule, cancel).
  assistant,

  /// Media playback/recording tools (audio, video, image editing).
  media,

  /// Communication tools (calls, SMS, email, messaging).
  communication,

  /// Navigation / location tools (maps, geofencing, routing).
  navigation,

  /// System-level tools (settings, package management, admin).
  system,

  /// Recovery / resilience tools (retry, fallback, rollback).
  recovery,

  /// Unknown / uncategorized tool. FAIL CLOSED → treated as highest risk.
  unknown,
}

/// Extension methods for [ToolCategory].
extension ToolCategoryX on ToolCategory {
  /// Human-readable label for this category (English, for logging).
  String get label => switch (this) {
        ToolCategory.voice => 'Voice',
        ToolCategory.screen => 'Screen',
        ToolCategory.vision => 'Vision',
        ToolCategory.device => 'Device',
        ToolCategory.memory => 'Memory',
        ToolCategory.assistant => 'Assistant',
        ToolCategory.media => 'Media',
        ToolCategory.communication => 'Communication',
        ToolCategory.navigation => 'Navigation',
        ToolCategory.system => 'System',
        ToolCategory.recovery => 'Recovery',
        ToolCategory.unknown => 'Unknown',
      };

  /// Whether this category implies high inherent risk.
  /// FAIL CLOSED: unknown → true.
  bool get isInherentlyRisky => switch (this) {
        ToolCategory.system => true,
        ToolCategory.communication => true,
        ToolCategory.device => true,
        ToolCategory.navigation => true,
        ToolCategory.unknown => true,
        _ => false,
      };

  /// Default confirmation policy for this category.
  /// FAIL CLOSED: unknown → always require confirmation.
  // ignore: unnecessary_null_comparison
  // (referenced by ConfirmationPolicy, defined in separate file)
  String get defaultConfirmationPolicyKey => switch (this) {
        ToolCategory.voice => 'never',
        ToolCategory.screen => 'whenSensitive',
        ToolCategory.vision => 'whenSensitive',
        ToolCategory.device => 'whenSensitive',
        ToolCategory.memory => 'whenSensitive',
        ToolCategory.assistant => 'whenSensitive',
        ToolCategory.media => 'whenSensitive',
        ToolCategory.communication => 'always',
        ToolCategory.navigation => 'whenSensitive',
        ToolCategory.system => 'always',
        ToolCategory.recovery => 'whenSensitive',
        ToolCategory.unknown => 'always',
      };
}
