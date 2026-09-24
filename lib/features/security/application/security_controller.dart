/// security_controller.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Application-layer controller that orchestrates all security services.
/// This is the primary entry point for security operations.
///
/// Coordinates:
/// - Secret scanning
/// - Data redaction
/// - Secure logging
/// - Security auditing
/// - Policy evaluation
/// - Integration with Steps 16, 17, 18
library;

import 'package:texo/core/errors/result.dart';
import '../domain/models/security_audit_entry.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_state.dart';
import '../domain/models/security_verdict.dart';
import '../domain/services/secret_scanner_service.dart';
import '../domain/services/sensitive_data_redactor.dart';
import 'security_policy.dart';

/// Abstract security controller — the main orchestrator.
abstract class SecurityController {
  /// Initialize the security system.
  ///
  /// Must be called before any other operations.
  /// FAIL CLOSED: if initialization fails, all operations are blocked.
  Future<SecurityResult<SecurityState>> initialize();

  /// Scan content for secrets.
  Future<SecurityResult<SecretScanResult>> scanForSecrets(String content);

  /// Redact sensitive data from content.
  Future<SecurityResult<RedactionResult>> redactContent(
    String content, {
    List<SensitiveDataCategory>? onlyCategories,
  });

  /// Evaluate a security check (via policy).
  Future<SecurityResult<SecurityVerdict>> evaluate(
    SecurityCheckContext context,
  );

  /// Evaluate an agent/tool action.
  Future<SecurityResult<SecurityVerdict>> evaluateAgentAction(
    String action, {
    String? content,
  });

  /// Evaluate a memory operation for privacy.
  Future<SecurityResult<SecurityVerdict>> evaluateMemoryOperation(
    String operation, {
    String? content,
  });

  /// Evaluate a permission request.
  Future<SecurityResult<SecurityVerdict>> evaluatePermission(
    String permissionId,
  );

  /// Evaluate content before sending to API provider.
  Future<SecurityResult<RedactionResult>> prepareContentForProvider(
    String content, {
    String provider = 'unknown',
  });

  /// Record a security audit event.
  Future<SecurityResult<SecurityAuditEntry>> recordAuditEvent(
    SecurityAuditEntry entry,
  );

  /// Get the current security state.
  SecurityState get currentState;

  /// Get the current security config.
  SecurityConfig get currentConfig;

  /// Update security configuration.
  Future<SecurityResult<SecurityConfig>> updateConfig(
    SecurityConfig config,
  );

  /// Check if the system is ready (initialized and healthy).
  bool get isReady;

  /// Stream of security state changes.
  Stream<SecurityState> get stateStream;
}
