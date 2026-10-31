/// audit_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 23 AuditRepository
///
/// Exact signature match from Step 23.
library;

/// Audit log entry (matches Step 23).
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

/// Abstract repository matching Step 23's AuditRepository.
/// record({action, description, timestamp, details}) → void
/// forRequest(requestId) → List<AuditLogEntry>
abstract class AuditRepository {
  void record({
    required String action,
    required String description,
    required DateTime timestamp,
    Map<String, dynamic>? details,
  });
  List<AuditLogEntry> forRequest(String requestId);
}
