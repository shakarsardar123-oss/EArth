/// Step 23 — Audit Adapter
///
/// Adapter implementing AuditRepository.
///
/// AuditRepository: record({required action, required description,
///   required timestamp, details?})→Future<void>,
///   forRequest(String requestId)→Future<List<AuditLogEntry>>.
/// NO isAvailable() — not in AuditRepository interface.
/// Uses record() with named params (not positional log()).
///
/// ── CLASSIFICATION: CLASS D (SELF-CONTAINED IN-MEMORY — NO MATCHING SINK) ──
/// AURA has a real security-audit facility
/// ([SecurityAuditService] / [DefaultSecurityAuditService], wired via
/// `securityAuditServiceProvider`), but its contract is
/// SECURITY-DECISION shaped (SecurityAuditEntry: verdict/policy/tool),
/// NOT the generic (action, description, timestamp, details) +
/// `forRequest(requestId)` retrieval contract this repository defines.
/// There is no persistent, request-indexed orchestration audit sink in
/// the codebase to delegate to.
///
/// This adapter is therefore self-contained on purpose: it keeps an
/// in-memory, per-instance list of [AuditLogEntry] so the orchestrator's
/// audit calls are honoured and `forRequest()` works within a session.
/// It does NOT compete with the security audit subsystem (different
/// concern, different contract).
///
/// REMAINING WORK: to persist across sessions and unify with the security
/// audit trail, add a mapping layer that forwards `record()` to a
/// persistent request-indexed store (or an adapted SecurityAuditService)
/// and reads `forRequest()` back from it.
/// ─────────────────────────────────────────────────────────────────────

import '../../domain/orchestration_domain.dart';

class AuditAdapter implements AuditRepository {
  /// In-memory audit log for structural validation.
  final List<AuditLogEntry> _entries = [];

  @override
  Future<void> record({
    required String action,
    required String description,
    required DateTime timestamp,
    Map<String, dynamic>? details,
  }) async {
    _entries.add(AuditLogEntry(
      action: action,
      description: description,
      timestamp: timestamp,
      details: details,
    ));
  }

  @override
  Future<List<AuditLogEntry>> forRequest(String requestId) async {
    return _entries
        .where((e) => e.details?['requestId'] == requestId)
        .toList();
  }
}
