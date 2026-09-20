/// security_audit_entry.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Lightweight audit entry for the secure audit log.
/// Contains only redacted/metadata information — NEVER raw secrets.
library;

import 'security_failure.dart';
import 'security_state.dart' show SecurityEventSeverity;
import 'security_verdict.dart';

/// The type of security event being audited.
enum SecurityAuditType {
  /// A secret was detected in content.
  secretDetected,

  /// Sensitive data was redacted from output.
  dataRedacted,

  /// An agent/tool action was validated.
  actionValidated,

  /// An action was blocked.
  actionBlocked,

  /// Memory privacy check was performed.
  memoryPrivacyCheck,

  /// Permission security check was performed.
  permissionCheck,

  /// API provider privacy check was performed.
  providerPrivacyCheck,

  /// Screen privacy event.
  screenPrivacyEvent,

  /// Voice privacy event.
  voicePrivacyEvent,

  /// Secure storage operation.
  secureStorageOp,

  /// Security config change.
  configChange,

  /// Security state initialization.
  initialization,

  /// Unknown event type — FAIL CLOSED: logged as critical.
  unknown,
}

/// An immutable audit log entry.
///
/// All fields are redacted/metadata — NEVER contains raw secrets
/// or unredacted sensitive data, even in debug builds.
class SecurityAuditEntry {
  /// Unique entry ID.
  final String id;

  /// Timestamp of the event.
  final DateTime timestamp;

  /// Type of security event.
  final SecurityAuditType type;

  /// Severity level.
  final SecurityEventSeverity severity;

  /// The action or operation involved.
  final String? action;

  /// The security verdict (if applicable).
  final SecurityVerdict? verdict;

  /// The sensitive data category (if applicable).
  final SensitiveDataCategory? category;

  /// Redacted description — safe for logging.
  final String redactedDescription;

  /// Optional metadata (keys only, no values from sensitive data).
  final Map<String, String> safeMetadata;

  const SecurityAuditEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.severity,
    this.action,
    this.verdict,
    this.category,
    required this.redactedDescription,
    this.safeMetadata = const {},
  });

  /// Convert to a safe map for secure storage.
  /// All values are redacted — no raw secrets.
  Map<String, dynamic> toSafeMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'severity': severity.name,
        if (action != null) 'action': action,
        if (verdict != null) 'verdict': verdict!.displayReason,
        if (category != null) 'category': category!.name,
        'description': redactedDescription,
        'metadata': safeMetadata,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityAuditEntry &&
          id == other.id &&
          timestamp == other.timestamp &&
          type == other.type &&
          severity == other.severity &&
          action == other.action &&
          verdict == other.verdict &&
          category == other.category &&
          redactedDescription == other.redactedDescription;

  @override
  int get hashCode => Object.hash(
        id,
        timestamp,
        type,
        severity,
        action,
        verdict,
        category,
        redactedDescription,
      );

  @override
  String toString() =>
      'SecurityAuditEntry(type: \${type.name}, severity: \${severity.name}, '
      'action: \$action, verdict: \${verdict?.displayReason})';
}
