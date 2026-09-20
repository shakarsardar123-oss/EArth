/// security_l10n_keys.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Localization key constants for the security feature.
/// Kurdish Sorani (RTL) is the primary language.
/// Key prefix: security_
///
/// Usage:
///   SStringsKu.current.security_feature_name   // Kurdish Sorani (primary)
///   SStringsEn.current.security_feature_name   // English
///   SStrings.current.security_feature_name     // Current locale
library;

class SecurityL10nKeys {
  SecurityL10nKeys._();

  // ─── Feature & General ─────────────────────────────────────────
  static const String featureName = 'security_feature_name';
  static const String featureDescription = 'security_feature_description';

  // ─── Security Config ────────────────────────────────────────────
  static const String configTitle = 'security_config_title';
  static const String configPrivacyLevel = 'security_config_privacy_level';
  static const String configPrivacyLevelMaximum = 'security_config_privacy_level_maximum';
  static const String configPrivacyLevelStandard = 'security_config_privacy_level_standard';
  static const String configPrivacyLevelMinimal = 'security_config_privacy_level_minimal';
  static const String configAgentSecurityMode = 'security_config_agent_security_mode';
  static const String configSecureLoggingMode = 'security_config_secure_logging_mode';
  static const String configScreenPrivacyMode = 'security_config_screen_privacy_mode';
  static const String configVoicePrivacyMode = 'security_config_voice_privacy_mode';
  static const String configProviderPrivacyMode = 'security_config_provider_privacy_mode';

  // ─── Security State ────────────────────────────────────────────
  static const String stateTitle = 'security_state_title';
  static const String stateSecretsDetected = 'security_state_secrets_detected';
  static const String stateBlockedActions = 'security_state_blocked_actions';
  static const String stateRedactionsPerformed = 'security_state_redactions_performed';
  static const String stateViolations = 'security_state_violations';
  static const String stateLoading = 'security_state_loading';
  static const String stateReady = 'security_state_ready';
  static const String stateActiveOperation = 'security_state_active_operation';

  // ─── Security Verdict ──────────────────────────────────────────
  static const String verdictAllowed = 'security_verdict_allowed';
  static const String verdictDenied = 'security_verdict_denied';
  static const String verdictFailClosed = 'security_verdict_fail_closed';
  static const String verdictReason = 'security_verdict_reason';

  // ─── Security Failure ─────────────────────────────────────────
  static const String failureBlocked = 'security_failure_blocked';
  static const String failureAction = 'security_failure_action';
  static const String failureCause = 'security_failure_cause';
  static const String failureCategory = 'security_failure_category';
  static const String failurePhase = 'security_failure_phase';

  // ─── Sensitive Data Categories ─────────────────────────────────
  static const String categoryPersonalData = 'security_category_personal_data';
  static const String categoryFinancialData = 'security_category_financial_data';
  static const String categoryHealthData = 'security_category_health_data';
  static const String categoryBiometricData = 'security_category_biometric_data';
  static const String categoryLocationData = 'security_category_location_data';
  static const String categoryAuthenticationToken = 'security_category_authentication_token';
  static const String categoryPassword = 'security_category_password';
  static const String categoryApiKey = 'security_category_api_key';
  static const String categoryEncryptionKey = 'security_category_encryption_key';
  static const String categoryPersonalIdentifier = 'security_category_personal_identifier';
  static const String categoryGovernmentId = 'security_category_government_id';
  static const String categoryCloudCredential = 'security_category_cloud_credential';
  static const String categoryDatabaseCredential = 'security_category_database_credential';
  static const String categoryNetworkIdentifier = 'security_category_network_identifier';
  static const String categoryDeviceIdentifier = 'security_category_device_identifier';
  static const String categoryBrowsingData = 'security_category_browsing_data';
  static const String categoryUnknown = 'security_category_unknown';

  // ─── Secret Scanning ──────────────────────────────────────────
  static const String secretScanTitle = 'security_secret_scan_title';
  static const String secretScanDetected = 'security_secret_scan_detected';
  static const String secretScanBlocked = 'security_secret_scan_blocked';
  static const String secretScanClean = 'security_secret_scan_clean';
  static const String secretScanInconclusive = 'security_secret_scan_inconclusive';

  // ─── Secure Logging ────────────────────────────────────────────
  static const String loggingTitle = 'security_logging_title';
  static const String loggingModeDisabled = 'security_logging_mode_disabled';
  static const String loggingModeMetadataOnly = 'security_logging_mode_metadata_only';
  static const String loggingModeRedactedOnly = 'security_logging_mode_redacted_only';
  static const String loggingModeDebugRedacted = 'security_logging_mode_debug_redacted';

  // ─── Redaction ─────────────────────────────────────────────────
  static const String redactionTitle = 'security_redaction_title';
  static const String redactionApplied = 'security_redaction_applied';
  static const String redactionOverRedacted = 'security_redaction_over_redacted';
  static const String redactionStrategyFullPlaceholder = 'security_redaction_strategy_full_placeholder';
  static const String redactionStrategyPartialMask = 'security_redaction_strategy_partial_mask';
  static const String redactionStrategyHashedPlaceholder = 'security_redaction_strategy_hashed_placeholder';
  static const String redactionStrategyCategoryOnly = 'security_redaction_strategy_category_only';

  // ─── Agent Security ────────────────────────────────────────────
  static const String agentSecurityTitle = 'security_agent_security_title';
  static const String agentActionDenied = 'security_agent_action_denied';
  static const String agentActionAllowed = 'security_agent_action_allowed';
  static const String agentRiskCritical = 'security_agent_risk_critical';
  static const String agentRiskHigh = 'security_agent_risk_high';
  static const String agentRiskMedium = 'security_agent_risk_medium';
  static const String agentRiskLow = 'security_agent_risk_low';
  static const String agentRiskUnknown = 'security_agent_risk_unknown';

  // ─── Provider Privacy ─────────────────────────────────────────
  static const String providerPrivacyTitle = 'security_provider_privacy_title';
  static const String providerContentPrepared = 'security_provider_content_prepared';
  static const String providerContentBlocked = 'security_provider_content_blocked';

  // ─── Screen Privacy ────────────────────────────────────────────
  static const String screenPrivacyTitle = 'security_screen_privacy_title';
  static const String screenSensitiveApp = 'security_screen_sensitive_app';
  static const String screenContentRedacted = 'security_screen_content_redacted';
  static const String screenModeFullCapture = 'security_screen_mode_full_capture';
  static const String screenModeSensitiveOnly = 'security_screen_mode_sensitive_only';
  static const String screenModeDisabled = 'security_screen_mode_disabled';

  // ─── Voice Privacy ─────────────────────────────────────────────
  static const String voicePrivacyTitle = 'security_voice_privacy_title';
  static const String voiceRecordingBlocked = 'security_voice_recording_blocked';
  static const String voiceTranscriptionRedacted = 'security_voice_transcription_redacted';
  static const String voiceSensitiveCommand = 'security_voice_sensitive_command';

  // ─── Permission Security ───────────────────────────────────────
  static const String permissionSecurityTitle = 'security_permission_security_title';
  static const String permissionBlockedBySecurity = 'security_permission_blocked_by_security';
  static const String permissionAllowedBySecurity = 'security_permission_allowed_by_security';
  static const String permissionRiskCritical = 'security_permission_risk_critical';
  static const String permissionRiskHigh = 'security_permission_risk_high';
  static const String permissionRiskMedium = 'security_permission_risk_medium';
  static const String permissionRiskLow = 'security_permission_risk_low';
  static const String permissionRiskUnknown = 'security_permission_risk_unknown';

  // ─── Secure Storage ────────────────────────────────────────────
  static const String storageTitle = 'security_storage_title';
  static const String storageWriteFailed = 'security_storage_write_failed';
  static const String storageReadFailed = 'security_storage_read_failed';
  static const String storageUnavailable = 'security_storage_unavailable';
  static const String storageCompromised = 'security_storage_compromised';

  // ─── Audit ─────────────────────────────────────────────────────
  static const String auditTitle = 'security_audit_title';
  static const String auditActionAllowed = 'security_audit_action_allowed';
  static const String auditActionDenied = 'security_audit_action_denied';
  static const String auditSecretDetected = 'security_audit_secret_detected';
  static const String auditConfigChanged = 'security_audit_config_changed';
  static const String auditSystemStartup = 'security_audit_system_startup';
  static const String auditRedactionPerformed = 'security_audit_redaction_performed';
  static const String auditPermissionCheck = 'security_audit_permission_check';
  static const String auditMemoryOperation = 'security_audit_memory_operation';
  static const String auditRecoveryAttempt = 'security_audit_recovery_attempt';
}
