/// advanced_agent_failure.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Failure types for the advanced agent (all 10 capabilities).
/// FAIL-CLOSED: unknown → denied/unrecoverable.
library;

/// Categories of failures that can occur during advanced agent execution.
enum AdvancedAgentFailureType {
  /// Planning failed to produce a valid plan.
  planningFailed,

  /// Replanning failed to adapt the plan.
  replanningFailed,

  /// Goal tracking encountered an error.
  goalTrackingFailed,

  /// Result verification failed.
  verificationFailed,

  /// Tool selection could not find a suitable tool.
  toolSelectionFailed,

  /// Context-aware execution failed or degraded.
  contextExecutionFailed,

  /// Natural language correction failed.
  correctionFailed,

  /// Task progress state tracking failed.
  progressTrackingFailed,

  /// Pause/resume/cancel operation failed.
  pauseResumeFailed,

  /// Safety gate denied the action.
  safetyDenied,

  /// Safety gate is unavailable (fail-closed → denied).
  safetyUnavailable,

  /// An external dependency (Steps 17-24) failed.
  dependencyFailed,

  /// Execution was cancelled by the user.
  cancelled,

  /// Unknown/unexpected error — fail-closed.
  unknown,
  ;

  /// FAIL-CLOSED: any unknown name maps to [unknown].
  static AdvancedAgentFailureType fromName(String name) {
    return AdvancedAgentFailureType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AdvancedAgentFailureType.unknown,
    );
  }

  /// Whether this failure type is recoverable.
  bool get isRecoverable =>
      this == AdvancedAgentFailureType.planningFailed ||
      this == AdvancedAgentFailureType.replanningFailed ||
      this == AdvancedAgentFailureType.toolSelectionFailed ||
      this == AdvancedAgentFailureType.contextExecutionFailed ||
      this == AdvancedAgentFailureType.correctionFailed ||
      this == AdvancedAgentFailureType.dependencyFailed;

  /// Whether this failure type is permanent (not recoverable).
  bool get isPermanent =>
      this == AdvancedAgentFailureType.safetyDenied ||
      this == AdvancedAgentFailureType.safetyUnavailable ||
      this == AdvancedAgentFailureType.cancelled ||
      this == AdvancedAgentFailureType.unknown;
}

/// A structured failure for the advanced agent.
class AdvancedAgentFailure {
  final String failureId;
  final AdvancedAgentFailureType type;
  final String message;
  final String? planId;
  final String? stepId;
  final String? toolId;
  final int retryAttempt;
  final String? originalError;
  final DateTime occurredAt;

  const AdvancedAgentFailure({
    required this.failureId,
    this.type = AdvancedAgentFailureType.unknown,
    this.message = 'An unknown error occurred.',
    this.planId,
    this.stepId,
    this.toolId,
    this.retryAttempt = 0,
    this.originalError,
    required this.occurredAt,
  });

  /// Whether the failure can potentially be recovered via retry/replan.
  bool get isRecoverable => type.isRecoverable && retryAttempt < 3;

  /// Whether the failure is permanent and should abort.
  bool get isPermanent => type.isPermanent || !isRecoverable;

  /// FAIL-CLOSED: factory for unknown failures.
  factory AdvancedAgentFailure.unknown({
    required String failureId,
    String message = 'Unknown failure — failing closed.',
    String? planId,
    String? stepId,
  }) =>
      AdvancedAgentFailure(
        failureId: failureId,
        type: AdvancedAgentFailureType.unknown,
        message: message,
        planId: planId,
        stepId: stepId,
        occurredAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for safety denial.
  factory AdvancedAgentFailure.safetyDenied({
    required String failureId,
    String? planId,
    String? stepId,
    String? toolId,
    String message = 'Action denied by safety gate (fail-closed).',
  }) =>
      AdvancedAgentFailure(
        failureId: failureId,
        type: AdvancedAgentFailureType.safetyDenied,
        message: message,
        planId: planId,
        stepId: stepId,
        toolId: toolId,
        occurredAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for safety unavailable.
  factory AdvancedAgentFailure.safetyUnavailable({
    required String failureId,
    String? planId,
  }) =>
      AdvancedAgentFailure(
        failureId: failureId,
        type: AdvancedAgentFailureType.safetyUnavailable,
        message: 'Safety gate unavailable — failing closed (denied).',
        planId: planId,
        occurredAt: DateTime.now(),
      );

  /// Factory: execution cancelled by user.
  factory AdvancedAgentFailure.cancelled({
    required String failureId,
    String? planId,
    String message = 'Execution cancelled by user.',
  }) =>
      AdvancedAgentFailure(
        failureId: failureId,
        type: AdvancedAgentFailureType.cancelled,
        message: message,
        planId: planId,
        occurredAt: DateTime.now(),
      );

  AdvancedAgentFailure copyWith({
    String? failureId,
    AdvancedAgentFailureType? type,
    String? message,
    String? planId,
    String? stepId,
    String? toolId,
    int? retryAttempt,
    String? originalError,
    DateTime? occurredAt,
  }) =>
      AdvancedAgentFailure(
        failureId: failureId ?? this.failureId,
        type: type ?? this.type,
        message: message ?? this.message,
        planId: planId ?? this.planId,
        stepId: stepId ?? this.stepId,
        toolId: toolId ?? this.toolId,
        retryAttempt: retryAttempt ?? this.retryAttempt,
        originalError: originalError ?? this.originalError,
        occurredAt: occurredAt ?? this.occurredAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedAgentFailure && failureId == other.failureId;

  @override
  int get hashCode => failureId.hashCode;

  @override
  String toString() =>
      'AdvancedAgentFailure(id: $failureId, type: $type, '
      'recoverable: $isRecoverable, msg: "$message")';
}
