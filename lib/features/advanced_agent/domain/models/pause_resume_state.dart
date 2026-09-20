/// pause_resume_state.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Pause/Resume/Cancel state (capability 9).
library;

/// State of a task regarding pause, resume, and cancel operations.
enum PauseResumeState {
  /// Task is actively running.
  running,

  /// Task has been paused and can be resumed.
  paused,

  /// Task has been cancelled and cannot be resumed.
  cancelled,

  /// Task is in the process of pausing (transition state).
  pausing,

  /// Task is in the process of resuming (transition state).
  resuming,
  ;

  /// FAIL-CLOSED: any unknown name maps to [paused] (safe default).
  static PauseResumeState fromName(String name) {
    return PauseResumeState.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PauseResumeState.paused,
    );
  }
}

/// Detailed pause/resume state record for a task or step.
class PauseResumeRecord {
  final String recordId;
  final String planId;
  final String? stepId;
  final PauseResumeState state;
  final String? reason;
  final String requestedBy;
  final DateTime changedAt;
  final String locale;

  const PauseResumeRecord({
    required this.recordId,
    required this.planId,
    this.stepId,
    this.state = PauseResumeState.running,
    this.reason,
    required this.requestedBy,
    required this.changedAt,
    this.locale = 'ku',
  });

  /// Whether the record represents an active pause.
  bool get isPaused => state == PauseResumeState.paused;

  /// Whether the record represents a cancellation.
  bool get isCancelled => state == PauseResumeState.cancelled;

  /// Whether the task/step can be resumed.
  bool get canResume =>
      state == PauseResumeState.paused ||
      state == PauseResumeState.pausing;

  /// Whether the task/step can be paused.
  bool get canPause =>
      state == PauseResumeState.running ||
      state == PauseResumeState.resuming;

  /// Whether the task/step can be cancelled.
  bool get canCancel =>
      state != PauseResumeState.cancelled;

  PauseResumeRecord copyWith({
    String? recordId,
    String? planId,
    String? stepId,
    PauseResumeState? state,
    String? reason,
    String? requestedBy,
    DateTime? changedAt,
    String? locale,
  }) =>
      PauseResumeRecord(
        recordId: recordId ?? this.recordId,
        planId: planId ?? this.planId,
        stepId: stepId ?? this.stepId,
        state: state ?? this.state,
        reason: reason ?? this.reason,
        requestedBy: requestedBy ?? this.requestedBy,
        changedAt: changedAt ?? this.changedAt,
        locale: locale ?? this.locale,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauseResumeRecord && recordId == other.recordId;

  @override
  int get hashCode => recordId.hashCode;

  @override
  String toString() =>
      'PauseResumeRecord(id: $recordId, plan: $planId, '
      'state: $state, by: $requestedBy)';
}
