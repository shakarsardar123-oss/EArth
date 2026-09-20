/// Step 23 — Orchestration Event
///
/// Represents a discrete event in the orchestration lifecycle.
/// Events trigger state transitions and are recorded for auditing.

import '../value_objects/orchestration_state.dart';

class OrchestrationEvent {
  final String eventId;
  final String requestId;
  final OrchestrationPhase fromPhase;
  final OrchestrationPhase toPhase;
  final String action;
  final String? description;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  const OrchestrationEvent({
    required this.eventId,
    required this.requestId,
    required this.fromPhase,
    required this.toPhase,
    required this.action,
    this.description,
    required this.timestamp,
    this.details,
  });

  @override
  String toString() =>
      'OrchestrationEvent($requestId: $fromPhase → $toPhase, action: $action)';
}
