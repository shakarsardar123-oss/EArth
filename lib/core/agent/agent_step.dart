import '../utils/uuid_util.dart';

import 'agent_step_status.dart';
import '../tools/tool_result.dart';
import '../../core/errors/result.dart';

/// A single step in the agent's plan.
///
/// Phase 4 adds: stepId, action, expectedResults, verificationCondition,
/// retryCount, maxRetries, status — all with defaults for backward compat.
class AgentStep {
  AgentStep({
    required this.toolName,
    required this.parameters,
    this.description,
    this.result,
    // ── Phase 4 additions (all have defaults) ──
    String? stepId,
    this.action,
    this.expectedResults,
    this.verificationCondition,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.status = AgentStepStatus.pending,
    this.error,
    this.startedAt,
    this.completedAt,
  }) : stepId = stepId ?? UuidUtil().v4();

  // ── Original fields (Phase 1–3) ──
  final String toolName;
  Map<String, dynamic> parameters;
  final String? description;
  ToolResult? result;

  // ── Phase 4 additions ──
  final String stepId;

  /// Human-readable action description (e.g. "Search contacts").
  final String? action;

  /// What we expect the tool to return.
  final String? expectedResults;

  /// Condition that must be true for verification to pass.
  final String? verificationCondition;

  /// How many times this step has been retried.
  int retryCount;

  /// Maximum retries allowed for this step.
  final int maxRetries;

  /// Current lifecycle status.
  AgentStepStatus status;

  /// Error message if the step failed.
  String? error;

  /// When this step started executing.
  DateTime? startedAt;

  /// When this step completed (succeeded, failed, or skipped).
  DateTime? completedAt;

  // ── Original computed properties (preserved) ──
  bool get isCompleted => result != null || status.isDone;
  bool get isSuccessful =>
      result?.isSuccess ?? status == AgentStepStatus.succeeded;

  /// Whether this step can still be retried.
  bool get canRetry => retryCount < maxRetries && !isDestructive;

  /// Whether this step performs a destructive action.
  /// Destructive steps should NOT be auto-retried.
  bool get isDestructive {
    const destructivePatterns = ['delete', 'remove', 'send', 'write'];
    final lower = toolName.toLowerCase();
    return destructivePatterns.any((p) => lower.contains(p));
  }

  /// Mark this step as completed with the given [result].
  void complete(ToolResult result) {
    this.result = result;
    status = result.isSuccess
        ? AgentStepStatus.succeeded
        : AgentStepStatus.failed;
    completedAt = DateTime.now();
    if (!result.isSuccess) {
      error = result.errorMessage;
    }
  }

  /// Mark the step as started.
  void markStarted() {
    status = AgentStepStatus.running;
    startedAt = DateTime.now();
  }

  /// Mark the step as skipped.
  void markSkipped({String? reason}) {
    status = AgentStepStatus.skipped;
    completedAt = DateTime.now();
    error = reason;
  }

  /// Record a retry attempt.
  void recordRetry() {
    retryCount++;
    status = AgentStepStatus.pending;
    result = null;
    error = null;
    startedAt = null;
    completedAt = null;
  }

  AgentStep copyWith({
    String? toolName,
    Map<String, dynamic>? parameters,
    String? description,
    ToolResult? result,
    String? stepId,
    String? action,
    String? expectedResults,
    String? verificationCondition,
    int? retryCount,
    int? maxRetries,
    AgentStepStatus? status,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return AgentStep(
      toolName: toolName ?? this.toolName,
      parameters: parameters ?? this.parameters,
      description: description ?? this.description,
      result: result ?? this.result,
      stepId: stepId ?? this.stepId,
      action: action ?? this.action,
      expectedResults: expectedResults ?? this.expectedResults,
      verificationCondition:
          verificationCondition ?? this.verificationCondition,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      status: status ?? this.status,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  String toString() =>
      'AgentStep($stepId, tool: $toolName, status: $status, retry: $retryCount/$maxRetries)';
}
