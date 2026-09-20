/// security_policy.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application-layer security policy engine.
/// Centralizes all security decision logic:
/// - Agent/tool action validation (integrates Step 16 ActionValidator)
/// - Memory privacy checks (integrates Step 17 MemoryPolicy)
/// - Permission security checks (integrates Step 16 CentralPermissionController)
/// - Provider privacy checks
/// - Screen/voice privacy checks
/// - Secret scanning + redaction orchestration
///
/// FAIL CLOSED: all decisions default to DENY when ambiguous.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_verdict.dart';

/// The type of security check being performed.
enum SecurityCheckType {
  agentAction,
  memoryAccess,
  permissionAccess,
  providerAccess,
  screenContent,
  voiceContent,
  dataRedaction,
  secretScanning,
  storageAccess,
}

/// Context for a security check.
class SecurityCheckContext {
  /// The type of check.
  final SecurityCheckType checkType;

  /// The action being checked (e.g., tool name, permission ID).
  final String action;

  /// The content being checked (e.g., text, prompt).
  final String? content;

  /// The source of the request (e.g., 'agent', 'user', 'provider').
  final String source;

  /// Additional context metadata (safe keys only).
  final Map<String, String> safeContext;

  const SecurityCheckContext({
    required this.checkType,
    required this.action,
    this.content,
    this.source = 'unknown',
    this.safeContext = const {},
  });
}

/// Abstract application-layer security policy.
///
/// This is the central decision point for all security checks.
/// It orchestrates scanning, redaction, validation, and audit.
abstract class SecurityPolicy {
  /// Evaluate a security check for the given [context].
  ///
  /// Returns a [SecurityVerdict] — allowed or denied.
  /// FAIL CLOSED: ambiguous → denied.
  Future<SecurityResult<SecurityVerdict>> evaluate(
    SecurityCheckContext context,
  );

  /// Evaluate an agent/tool action for security.
  ///
  /// Integrates with Step 16 ActionValidator and ProhibitedActionsRegistry.
  Future<SecurityResult<SecurityVerdict>> evaluateAgentAction(
    String action, {
    String? content,
    Map<String, String> safeContext = const {},
  });

  /// Evaluate a memory operation for privacy.
  ///
  /// Integrates with Step 17 MemoryPolicy.
  Future<SecurityResult<SecurityVerdict>> evaluateMemoryOperation(
    String operation, {
    String? content,
    Map<String, String> safeContext = const {},
  });

  /// Evaluate a permission request for security.
  ///
  /// Integrates with Step 16 CentralPermissionController.
  Future<SecurityResult<SecurityVerdict>> evaluatePermission(
    String permissionId, {
    Map<String, String> safeContext = const {},
  });

  /// Evaluate content for provider privacy (before sending to API).
  Future<SecurityResult<SecurityVerdict>> evaluateProviderContent(
    String content, {
    String provider = 'unknown',
    Map<String, String> safeContext = const {},
  });

  /// Get the current security configuration.
  SecurityConfig get currentConfig;

  /// Update the security configuration.
  /// Returns the updated config, or failure if invalid.
  Future<SecurityResult<SecurityConfig>> updateConfig(
    SecurityConfig config,
  );

  /// Reset to default configuration.
  Future<SecurityResult<SecurityConfig>> resetToDefaults();
}
