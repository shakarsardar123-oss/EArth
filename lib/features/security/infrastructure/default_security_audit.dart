/// default_security_audit.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Default infrastructure implementation of SecurityAuditService.
/// In-memory storage with optional secure storage backend.
///
/// FAIL CLOSED: on query error, returns empty results (no data leak).
library;

import 'package:aura_assistant/core/errors/result.dart' show Result, Success, FailureResult;
import '../domain/models/security_audit_entry.dart';
import '../domain/models/security_config.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_state.dart';
import '../domain/models/security_verdict.dart';
import '../domain/services/security_audit_service.dart';

class DefaultSecurityAuditService implements SecurityAuditService {
  final List<SecurityAuditEntry> _entries = [];
  static const int _maxEntries = 5000;
  SecurityConfig _config;

  DefaultSecurityAuditService({
    required SecurityConfig config,
  }) : _config = config;

  @override
  Future<SecurityResult<SecurityAuditEntry>> record(
    SecurityAuditEntry entry,
  ) async {
    try {
      _entries.add(entry);
      _trimIfNeeded();
      return Success(entry);
    } catch (_) {
      return SecurityFailure.auditFailed(
        action: 'record',
        cause: 'Failed to record audit entry',
      ).asFailure<SecurityAuditEntry>();
    }
  }

  @override
  Future<SecurityResult<SecurityAuditEntry>> recordVerdict(
    String action,
    SecurityVerdict verdict, {
    SensitiveDataCategory? category,
    Map<String, String> safeMetadata = const {},
  }) async {
    try {
      final entry = SecurityAuditEntry(
        id: _generateId(),
        timestamp: DateTime.now(),
        type: verdict.isDenied
            ? SecurityAuditType.actionBlocked
            : SecurityAuditType.actionValidated,
        severity: verdict.isFailClosedDenial
            ? SecurityEventSeverity.critical
            : verdict.isDenied
                ? SecurityEventSeverity.warning
                : SecurityEventSeverity.info,
        action: action,
        verdict: verdict,
        category: category ?? verdict.category,
        redactedDescription:
            '[VERDICT] ${verdict.isDenied ? "DENIED" : "ALLOWED"}: ${verdict.displayReason}',
        safeMetadata: {
          'fail_closed': verdict.isFailClosedDenial.toString(),
          'explicitly_denied': verdict.isExplicitlyDenied.toString(),
          ...safeMetadata,
        },
      );
      return record(entry);
    } catch (_) {
      return SecurityFailure.auditFailed(
        action: 'recordVerdict',
        cause: 'Failed to record verdict audit',
      ).asFailure<SecurityAuditEntry>();
    }
  }

  @override
  Future<SecurityResult<List<SecurityAuditEntry>>> query(
    AuditQuery query,
  ) async {
    try {
      var results = _entries;

      // Filter by time range
      if (query.from != null) {
        results = results
            .where((e) => e.timestamp.isAfter(query.from!))
            .toList();
      }
      if (query.to != null) {
        results = results
            .where((e) => e.timestamp.isBefore(query.to!))
            .toList();
      }

      // Filter by type
      if (query.type != null) {
        results = results
            .where((e) => e.type == query.type)
            .toList();
      }

      // Filter by action
      if (query.action != null) {
        results = results
            .where((e) => e.action == query.action)
            .toList();
      }

      // Filter by severity
      if (query.minSeverity != null) {
        final minIndex =
            SecurityEventSeverity.values.indexOf(query.minSeverity!);
        results = results
            .where((e) =>
                SecurityEventSeverity.values.indexOf(e.severity) >=
                minIndex)
            .toList();
      }

      // Filter by category
      if (query.category != null) {
        results = results
            .where((e) => e.category == query.category)
            .toList();
      }

      // Apply limit and offset
      final start = query.offset;
      final end = start + query.limit;
      if (start < results.length) {
        results = results.sublist(
          start,
          end > results.length ? results.length : end,
        );
      } else {
        results = [];
      }

      return Success(results);
    } catch (_) {
      // FAIL CLOSED: return empty on error, never leak data
      return Success([]);
    }
  }

  @override
  Future<SecurityResult<AuditSummary>> getSummary() async {
    try {
      var relevant = _entries;

      final byType = <SecurityAuditType, int>{};
      final bySeverity = <SecurityEventSeverity, int>{};
      final byCategory = <SensitiveDataCategory, int>{};

      int secretsDetected = 0;
      int actionsBlocked = 0;
      int redactionsApplied = 0;
      int privacyViolations = 0;

      for (final entry in relevant) {
        byType[entry.type] = (byType[entry.type] ?? 0) + 1;
        bySeverity[entry.severity] =
            (bySeverity[entry.severity] ?? 0) + 1;
        if (entry.category != null) {
          byCategory[entry.category!] =
              (byCategory[entry.category!] ?? 0) + 1;
        }

        // Count by type for summary
        switch (entry.type) {
          case SecurityAuditType.secretDetected:
            secretsDetected++;
          case SecurityAuditType.actionBlocked:
            actionsBlocked++;
          case SecurityAuditType.dataRedacted:
            redactionsApplied++;
          case SecurityAuditType.screenPrivacyEvent:
          case SecurityAuditType.voicePrivacyEvent:
          case SecurityAuditType.providerPrivacyCheck:
            privacyViolations++;
          default:
            break;
        }
      }

      return Success(AuditSummary(
        totalEvents: relevant.length,
        secretsDetected: secretsDetected,
        actionsBlocked: actionsBlocked,
        redactionsApplied: redactionsApplied,
        privacyViolations: privacyViolations,
        firstEventTime: relevant.isNotEmpty ? relevant.first.timestamp : null,
        lastEventTime: relevant.isNotEmpty ? relevant.last.timestamp : null,
      ));
    } catch (_) {
      // FAIL CLOSED: return empty summary on error
      return Success(const AuditSummary(
        totalEvents: 0,
      ));
    }
  }

  @override
  Future<SecurityResult<int>> purgeOldEntries(
    int retentionDays,
  ) async {
    try {
      final cutoff =
          DateTime.now().subtract(Duration(days: retentionDays));
      final removed = _entries
          .where((e) => e.timestamp.isBefore(cutoff))
          .length;
      _entries.removeWhere((e) => e.timestamp.isBefore(cutoff));
      return Success(removed);
    } catch (_) {
      return SecurityFailure.auditFailed(
        action: 'purgeOldEntries',
        cause: 'Failed to purge audit entries',
      ).asFailure<int>();
    }
  }

  @override
  Future<SecurityResult<int>> get entryCount async {
    try {
      return Success(_entries.length);
    } catch (_) {
      return Success(0); // FAIL CLOSED
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────

  void _trimIfNeeded() {
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }

  String _generateId() =>
      'audit_${DateTime.now().millisecondsSinceEpoch}';
}
