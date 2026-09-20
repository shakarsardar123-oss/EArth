/// security_config.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Immutable security & privacy configuration model.
/// Controls all 14 capabilities via toggleable settings.
/// FAIL CLOSED: when a setting is missing or ambiguous,
/// the most restrictive interpretation is used.
library;

import 'package:flutter/foundation.dart';
import 'redaction_rule.dart';
import 'security_failure.dart';

/// Privacy level preset for the user.
enum PrivacyLevel {
  /// Maximum privacy — all protections enabled, over-redact.
  maximum,

  /// Standard privacy — balanced protection.
  standard,

  /// Minimal privacy — only critical protections enabled.
  /// FAIL CLOSED: even at minimal, secrets are ALWAYS protected.
  minimal,
}

/// Security mode for agent/tool actions.
enum AgentSecurityMode {
  /// All actions require explicit allow-list entry.
  /// Unknown actions → BLOCKED (fail-closed).
  strictAllowlist,

  /// Known-safe actions auto-allowed; unknown → blocked.
  conservativeAllow,

  /// Most actions allowed; known-dangerous blocked.
  /// FAIL CLOSED: even in permissive mode, prohibited actions
  /// from Step 16 ProhibitedActionsRegistry are blocked.
  permissiveBlocklist,
}

/// Logging mode for secure logging.
enum SecureLoggingMode {
  /// No logging at all (most private).
  disabled,

  /// Log events with all sensitive data redacted.
  redactedOnly,

  /// Log events with metadata only (no content, even redacted).
  metadataOnly,

  /// Debug mode — verbose but still redacted.
  /// NEVER logs raw secrets even in debug.
  debugRedacted,
}

/// Screen privacy mode for screen/vision content.
enum ScreenPrivacyMode {
  /// Full screen protection — content never leaves device unencrypted.
  fullProtection,

  /// Protection only when sensitive apps are detected on screen.
  sensitiveAppsOnly,

  /// No screen privacy — FAIL CLOSED: minimum protection still applies.
  none,
}

/// Voice privacy mode for voice/audio content.
enum VoicePrivacyMode {
  /// Full voice protection — audio processed locally only.
  fullProtection,

  /// Protection only for sensitive commands.
  sensitiveCommandsOnly,

  /// No voice privacy — FAIL CLOSED: minimum protection still applies.
  none,
}

/// Provider privacy mode for API provider interactions.
enum ProviderPrivacyMode {
  /// Strip all PII before sending to any provider.
  stripAllPII,

  /// Strip sensitive PII only (credentials, financial, health).
  stripSensitiveOnly,

  /// No PII stripping — FAIL CLOSED: minimum still enforced.
  none,
}

/// @immutable security & privacy configuration.
///
/// Controls all 14 capabilities. Every field has a FAIL CLOSED default:
/// - If null/missing, the most restrictive interpretation is used.
/// - [privacyLevel] controls defaults for unset sub-settings.
@immutable
class SecurityConfig {
  /// Overall privacy level preset.
  final PrivacyLevel privacyLevel;

  /// Security mode for agent/tool actions.
  final AgentSecurityMode agentSecurityMode;

  /// Secure logging mode.
  final SecureLoggingMode loggingMode;

  /// Screen privacy mode.
  final ScreenPrivacyMode screenPrivacyMode;

  /// Voice privacy mode.
  final VoicePrivacyMode voicePrivacyMode;

  /// Provider privacy mode.
  final ProviderPrivacyMode providerPrivacyMode;

  /// Whether secret scanning is enabled.
  /// FAIL CLOSED: if null, defaults to true.
  final bool secretScanningEnabled;

  /// Whether sensitive data redaction is enabled.
  /// FAIL CLOSED: if null, defaults to true.
  final bool redactionEnabled;

  /// Whether memory privacy integration with Step 17 is active.
  final bool memoryPrivacyEnabled;

  /// Whether permission security integration with Step 16 is active.
  final bool permissionSecurityEnabled;

  /// Whether secure local storage is enabled.
  final bool secureStorageEnabled;

  /// Custom redaction rules (overrides defaults when present).
  final List<RedactionRule> customRedactionRules;

  /// List of explicitly allowed agent actions (allow-list).
  /// FAIL CLOSED: if empty, all actions require validation.
  final List<String> allowedAgentActions;

  /// List of explicitly denied agent actions (deny-list).
  /// FAIL CLOSED: denied list always takes precedence.
  final List<String> deniedAgentActions;

  /// List of sensitive app package names for screen privacy.
  final List<String> sensitiveAppPackages;

  /// Whether to auto-redact clipboard content.
  final bool autoRedactClipboard;

  /// Whether to protect screen captures from exfiltration.
  final bool screenCaptureProtection;

  /// Whether to protect voice recordings from exfiltration.
  final bool voiceRecordingProtection;

  /// Maximum audit log retention in days.
  final int auditLogRetentionDays;

  const SecurityConfig({
    this.privacyLevel = PrivacyLevel.standard,
    this.agentSecurityMode = AgentSecurityMode.conservativeAllow,
    this.loggingMode = SecureLoggingMode.redactedOnly,
    this.screenPrivacyMode = ScreenPrivacyMode.sensitiveAppsOnly,
    this.voicePrivacyMode = VoicePrivacyMode.sensitiveCommandsOnly,
    this.providerPrivacyMode = ProviderPrivacyMode.stripSensitiveOnly,
    this.secretScanningEnabled = true,
    this.redactionEnabled = true,
    this.memoryPrivacyEnabled = true,
    this.permissionSecurityEnabled = true,
    this.secureStorageEnabled = true,
    this.customRedactionRules = const [],
    this.allowedAgentActions = const [],
    this.deniedAgentActions = const [],
    this.sensitiveAppPackages = const [],
    this.autoRedactClipboard = false,
    this.screenCaptureProtection = true,
    this.voiceRecordingProtection = true,
    this.auditLogRetentionDays = 90,
  });

  /// Maximum-privacy factory — all protections on, most restrictive.
  factory SecurityConfig.maximum() => const SecurityConfig(
        privacyLevel: PrivacyLevel.maximum,
        agentSecurityMode: AgentSecurityMode.strictAllowlist,
        loggingMode: SecureLoggingMode.metadataOnly,
        screenPrivacyMode: ScreenPrivacyMode.fullProtection,
        voicePrivacyMode: VoicePrivacyMode.fullProtection,
        providerPrivacyMode: ProviderPrivacyMode.stripAllPII,
        secretScanningEnabled: true,
        redactionEnabled: true,
        memoryPrivacyEnabled: true,
        permissionSecurityEnabled: true,
        secureStorageEnabled: true,
        autoRedactClipboard: true,
        screenCaptureProtection: true,
        voiceRecordingProtection: true,
        auditLogRetentionDays: 30,
      );

  /// Minimal-privacy factory — only critical protections.
  /// FAIL CLOSED: secrets STILL protected even at minimal.
  factory SecurityConfig.minimal() => const SecurityConfig(
        privacyLevel: PrivacyLevel.minimal,
        agentSecurityMode: AgentSecurityMode.permissiveBlocklist,
        loggingMode: SecureLoggingMode.redactedOnly,
        screenPrivacyMode: ScreenPrivacyMode.none,
        voicePrivacyMode: VoicePrivacyMode.none,
        providerPrivacyMode: ProviderPrivacyMode.stripSensitiveOnly,
        secretScanningEnabled: true, // ALWAYS on
        redactionEnabled: true, // ALWAYS on
        memoryPrivacyEnabled: true, // ALWAYS on
        permissionSecurityEnabled: true, // ALWAYS on
        secureStorageEnabled: true, // ALWAYS on
        autoRedactClipboard: false,
        screenCaptureProtection: false,
        voiceRecordingProtection: false,
        auditLogRetentionDays: 365,
      );

  // ─── Convenience getters ──────────────────────────────────────────

  /// Whether secret scanning MUST be enabled (FAIL CLOSED invariant).
  bool get isSecretScanningForced => true;

  /// Whether redaction MUST be enabled (FAIL CLOSED invariant).
  bool get isRedactionForced => true;

  /// Whether memory privacy MUST be enabled (FAIL CLOSED invariant).
  bool get isMemoryPrivacyForced => true;

  /// Whether an action is in the deny-list.
  bool isActionDenied(String action) =>
      deniedAgentActions.contains(action);

  /// Whether an action is in the allow-list.
  bool isActionAllowed(String action) =>
      allowedAgentActions.contains(action);

  /// Whether a given [PrivacyLevel] or stricter is active.
  bool isAtLeast(PrivacyLevel level) {
    const order = [
      PrivacyLevel.minimal,
      PrivacyLevel.standard,
      PrivacyLevel.maximum,
    ];
    return order.indexOf(privacyLevel) >= order.indexOf(level);
  }

  /// Copy with overrides.
  SecurityConfig copyWith({
    PrivacyLevel? privacyLevel,
    AgentSecurityMode? agentSecurityMode,
    SecureLoggingMode? loggingMode,
    ScreenPrivacyMode? screenPrivacyMode,
    VoicePrivacyMode? voicePrivacyMode,
    ProviderPrivacyMode? providerPrivacyMode,
    bool? secretScanningEnabled,
    bool? redactionEnabled,
    bool? memoryPrivacyEnabled,
    bool? permissionSecurityEnabled,
    bool? secureStorageEnabled,
    List<RedactionRule>? customRedactionRules,
    List<String>? allowedAgentActions,
    List<String>? deniedAgentActions,
    List<String>? sensitiveAppPackages,
    bool? autoRedactClipboard,
    bool? screenCaptureProtection,
    bool? voiceRecordingProtection,
    int? auditLogRetentionDays,
    bool clearCustomRedactionRules = false,
    bool clearAllowedAgentActions = false,
    bool clearDeniedAgentActions = false,
    bool clearSensitiveAppPackages = false,
  }) {
    return SecurityConfig(
      privacyLevel: privacyLevel ?? this.privacyLevel,
      agentSecurityMode: agentSecurityMode ?? this.agentSecurityMode,
      loggingMode: loggingMode ?? this.loggingMode,
      screenPrivacyMode: screenPrivacyMode ?? this.screenPrivacyMode,
      voicePrivacyMode: voicePrivacyMode ?? this.voicePrivacyMode,
      providerPrivacyMode: providerPrivacyMode ?? this.providerPrivacyMode,
      secretScanningEnabled: secretScanningEnabled ?? this.secretScanningEnabled,
      redactionEnabled: redactionEnabled ?? this.redactionEnabled,
      memoryPrivacyEnabled: memoryPrivacyEnabled ?? this.memoryPrivacyEnabled,
      permissionSecurityEnabled:
          permissionSecurityEnabled ?? this.permissionSecurityEnabled,
      secureStorageEnabled: secureStorageEnabled ?? this.secureStorageEnabled,
      customRedactionRules: clearCustomRedactionRules
          ? const []
          : (customRedactionRules ?? this.customRedactionRules),
      allowedAgentActions: clearAllowedAgentActions
          ? const []
          : (allowedAgentActions ?? this.allowedAgentActions),
      deniedAgentActions: clearDeniedAgentActions
          ? const []
          : (deniedAgentActions ?? this.deniedAgentActions),
      sensitiveAppPackages: clearSensitiveAppPackages
          ? const []
          : (sensitiveAppPackages ?? this.sensitiveAppPackages),
      autoRedactClipboard: autoRedactClipboard ?? this.autoRedactClipboard,
      screenCaptureProtection:
          screenCaptureProtection ?? this.screenCaptureProtection,
      voiceRecordingProtection:
          voiceRecordingProtection ?? this.voiceRecordingProtection,
      auditLogRetentionDays:
          auditLogRetentionDays ?? this.auditLogRetentionDays,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityConfig &&
          privacyLevel == other.privacyLevel &&
          agentSecurityMode == other.agentSecurityMode &&
          loggingMode == other.loggingMode &&
          screenPrivacyMode == other.screenPrivacyMode &&
          voicePrivacyMode == other.voicePrivacyMode &&
          providerPrivacyMode == other.providerPrivacyMode &&
          secretScanningEnabled == other.secretScanningEnabled &&
          redactionEnabled == other.redactionEnabled &&
          memoryPrivacyEnabled == other.memoryPrivacyEnabled &&
          permissionSecurityEnabled == other.permissionSecurityEnabled &&
          secureStorageEnabled == other.secureStorageEnabled &&
          _listEq(customRedactionRules, other.customRedactionRules) &&
          _listEq(allowedAgentActions, other.allowedAgentActions) &&
          _listEq(deniedAgentActions, other.deniedAgentActions) &&
          _listEq(sensitiveAppPackages, other.sensitiveAppPackages) &&
          autoRedactClipboard == other.autoRedactClipboard &&
          screenCaptureProtection == other.screenCaptureProtection &&
          voiceRecordingProtection == other.voiceRecordingProtection &&
          auditLogRetentionDays == other.auditLogRetentionDays;

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        privacyLevel,
        agentSecurityMode,
        loggingMode,
        screenPrivacyMode,
        voicePrivacyMode,
        providerPrivacyMode,
        secretScanningEnabled,
        redactionEnabled,
        memoryPrivacyEnabled,
        permissionSecurityEnabled,
        secureStorageEnabled,
        Object.hashAll(customRedactionRules),
        Object.hashAll(allowedAgentActions),
        Object.hashAll(deniedAgentActions),
        Object.hashAll(sensitiveAppPackages),
        autoRedactClipboard,
        screenCaptureProtection,
        voiceRecordingProtection,
        auditLogRetentionDays,
      );

  @override
  String toString() =>
      'SecurityConfig(privacyLevel: \$privacyLevel, '
      'agentSecurity: \$agentSecurityMode, logging: \$loggingMode)';
}
