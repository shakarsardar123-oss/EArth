/// Step 23 — Audit Repository Interface
///
/// Contract for recording orchestration events for auditing.
/// Per Step 22 contract: AuditEntry has action/description/timestamp/details — NO phase.

abstract class AuditRepository {
  /// Record an orchestration event.
  Future<void> record({
    required String action,
    required String description,
    required DateTime timestamp,
    Map<String, dynamic>? details,
  });

  /// Retrieve audit log for a specific request.
  Future<List<AuditLogEntry>> forRequest(String requestId);
}

class AuditLogEntry {
  final String action;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  const AuditLogEntry({
    required this.action,
    required this.description,
    required this.timestamp,
    this.details,
  });
}
