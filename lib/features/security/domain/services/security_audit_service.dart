/// security_audit_service.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Domain service interface for security auditing.
/// Maintains a secure, redacted audit trail of all security events.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../models/security_audit_entry.dart';
import '../models/security_state.dart' show SecurityEventSeverity;
import '../models/security_failure.dart';
import '../models/security_verdict.dart';

/// Query parameters for searching audit entries.
class AuditQuery {
  /// Filter by audit type.
  final SecurityAuditType? type;

  /// Filter by severity (minimum).
  final SecurityEventSeverity? minSeverity;

  /// Filter by action name.
  final String? action;

  /// Filter by category.
  final SensitiveDataCategory? category;

  /// Filter by time range.
  final DateTime? from;
  final DateTime? to;

  /// Maximum number of results.
  final int limit;

  /// Offset for pagination.
  final int offset;

  const AuditQuery({
    this.type,
    this.minSeverity,
    this.action,
    this.category,
    this.from,
    this.to,
    this.limit = 50,
    this.offset = 0,
  });
}

/// Summary statistics of the audit log.
class AuditSummary {
  final int totalEvents;
  final int secretsDetected;
  final int actionsBlocked;
  final int redactionsApplied;
  final int privacyViolations;
  final DateTime? firstEventTime;
  final DateTime? lastEventTime;

  const AuditSummary({
    this.totalEvents = 0,
    this.secretsDetected = 0,
    this.actionsBlocked = 0,
    this.redactionsApplied = 0,
    this.privacyViolations = 0,
    this.firstEventTime,
    this.lastEventTime,
  });

  @override
  String toString() =>
      'AuditSummary(total: \$totalEvents, secrets: \$secretsDetected, '
      'blocked: \$actionsBlocked, redactions: \$redactionsApplied, '
      'violations: \$privacyViolations)';
}

/// Abstract domain service for security auditing.
///
/// All audit entries are:
/// - Stored in secure local storage (encrypted).
/// - Redacted — no raw secrets or sensitive data in entries.
/// - Tamper-evident — entries cannot be silently removed.
///
/// FAIL CLOSED: if audit logging fails, the action that triggered
/// the audit event is blocked (cannot proceed without audit trail).
abstract class SecurityAuditService {
  /// Record a security audit entry.
  ///
  /// Returns the stored entry on success, or [SecurityFailure] on error.
  /// FAIL CLOSED: if recording fails, the triggering action is blocked.
  Future<SecurityResult<SecurityAuditEntry>> record(SecurityAuditEntry entry);

  /// Query audit entries matching [query].
  Future<SecurityResult<List<SecurityAuditEntry>>> query(AuditQuery query);

  /// Get summary statistics.
  Future<SecurityResult<AuditSummary>> getSummary();

  /// Purge entries older than [retentionDays].
  /// Returns the count of purged entries.
  Future<SecurityResult<int>> purgeOldEntries(int retentionDays);

  /// Get the total number of stored audit entries.
  Future<SecurityResult<int>> get entryCount;

  /// Record a verdict-based audit entry (convenience method).
  Future<SecurityResult<SecurityAuditEntry>> recordVerdict(
    String action,
    SecurityVerdict verdict, {
    SensitiveDataCategory? category,
    Map<String, String> safeMetadata = const {},
  });
}
