/// advanced_agent_result.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Top-level result type for the advanced agent task execution.
/// FAIL-CLOSED: unknown → denied, error → failed.
library;

import 'advanced_agent_failure.dart';
import '../../../../core/errors/result.dart';

/// Overall status of an advanced agent task execution.
enum AdvancedAgentResultStatus {
  /// Task completed successfully.
  success,

  /// Task failed (may be recoverable).
  failed,

  /// Task was denied by safety gate or security.
  denied,

  /// Task was cancelled by the user.
  cancelled,

  /// Task executed in offline/degraded mode.
  offlineDegraded,

  /// Unknown result — FAIL-CLOSED → treated as denied.
  unknown,
  ;

  /// FAIL-CLOSED: any unknown name maps to [unknown].
  static AdvancedAgentResultStatus fromName(String name) {
    return AdvancedAgentResultStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AdvancedAgentResultStatus.unknown,
    );
  }

  /// Whether this status is considered a terminal failure.
  bool get isFailure =>
      this == AdvancedAgentResultStatus.failed ||
      this == AdvancedAgentResultStatus.denied ||
      this == AdvancedAgentResultStatus.cancelled ||
      this == AdvancedAgentResultStatus.unknown;
}

/// Comprehensive result of an advanced agent task execution.
/// Wraps the output data and any failures encountered.
class AdvancedAgentResult {
  final String resultId;
  final AdvancedAgentResultStatus status;
  final String? planId;
  final String? requestId;
  final Map<String, dynamic> outputData;
  final List<AdvancedAgentFailure> failures;
  final String? executionLog;
  final Duration? executionDuration;
  final String locale;
  final DateTime completedAt;

  const AdvancedAgentResult({
    required this.resultId,
    this.status = AdvancedAgentResultStatus.unknown,
    this.planId,
    this.requestId,
    this.outputData = const {},
    this.failures = const [],
    this.executionLog,
    this.executionDuration,
    this.locale = 'ku',
    required this.completedAt,
  });

  /// Whether the result represents a successful execution.
  bool get isSuccess => status == AdvancedAgentResultStatus.success;

  /// Whether the result represents a failure of any kind.
  bool get isFailure => status.isFailure;

  /// Whether the result was degraded (offline mode).
  bool get isDegraded =>
      status == AdvancedAgentResultStatus.offlineDegraded;

  /// Whether the result was denied by safety/security.
  bool get isDenied => status == AdvancedAgentResultStatus.denied;

  /// Whether any failures are recoverable.
  bool get hasRecoverableFailures =>
      failures.any((f) => f.isRecoverable);

  /// FAIL-CLOSED: factory for success.
  factory AdvancedAgentResult.success({
    required String resultId,
    String? planId,
    String? requestId,
    Map<String, dynamic> outputData = const {},
    String? executionLog,
    Duration? executionDuration,
    String locale = 'ku',
  }) =>
      AdvancedAgentResult(
        resultId: resultId,
        status: AdvancedAgentResultStatus.success,
        planId: planId,
        requestId: requestId,
        outputData: outputData,
        executionLog: executionLog,
        executionDuration: executionDuration,
        locale: locale,
        completedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for denied result.
  factory AdvancedAgentResult.denied({
    required String resultId,
    String? planId,
    String? requestId,
    List<AdvancedAgentFailure> failures = const [],
    String? executionLog,
    String locale = 'ku',
  }) =>
      AdvancedAgentResult(
        resultId: resultId,
        status: AdvancedAgentResultStatus.denied,
        planId: planId,
        requestId: requestId,
        failures: failures,
        executionLog: executionLog,
        locale: locale,
        completedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for cancelled result.
  factory AdvancedAgentResult.cancelled({
    required String resultId,
    String? planId,
    String? requestId,
    String? executionLog,
    String locale = 'ku',
  }) =>
      AdvancedAgentResult(
        resultId: resultId,
        status: AdvancedAgentResultStatus.cancelled,
        planId: planId,
        requestId: requestId,
        failures: [
          AdvancedAgentFailure.cancelled(failureId: '${resultId}_cancel'),
        ],
        executionLog: executionLog,
        locale: locale,
        completedAt: DateTime.now(),
      );

  /// Factory for failed result.
  factory AdvancedAgentResult.failed({
    required String resultId,
    required List<AdvancedAgentFailure> failures,
    String? planId,
    String? requestId,
    String? executionLog,
    Duration? executionDuration,
    String locale = 'ku',
  }) =>
      AdvancedAgentResult(
        resultId: resultId,
        status: AdvancedAgentResultStatus.failed,
        planId: planId,
        requestId: requestId,
        failures: failures,
        executionLog: executionLog,
        executionDuration: executionDuration,
        locale: locale,
        completedAt: DateTime.now(),
      );

  /// Factory for offline degraded result.
  factory AdvancedAgentResult.offlineDegraded({
    required String resultId,
    String? planId,
    String? requestId,
    Map<String, dynamic> outputData = const {},
    List<AdvancedAgentFailure> failures = const [],
    String? executionLog,
    Duration? executionDuration,
    String locale = 'ku',
  }) =>
      AdvancedAgentResult(
        resultId: resultId,
        status: AdvancedAgentResultStatus.offlineDegraded,
        planId: planId,
        requestId: requestId,
        outputData: outputData,
        failures: failures,
        executionLog: executionLog,
        executionDuration: executionDuration,
        locale: locale,
        completedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: factory for unknown → denied.
  factory AdvancedAgentResult.unknown({
    required String resultId,
    String? planId,
    String? requestId,
    String? executionLog,
    String locale = 'ku',
  }) =>
      AdvancedAgentResult.denied(
        resultId: resultId,
        planId: planId,
        requestId: requestId,
        failures: [
          AdvancedAgentFailure.unknown(
            failureId: '${resultId}_unknown',
            message: 'Unknown result — failing closed (denied).',
          ),
        ],
        executionLog: executionLog,
        locale: locale,
      );

  AdvancedAgentResult copyWith({
    String? resultId,
    AdvancedAgentResultStatus? status,
    String? planId,
    String? requestId,
    Map<String, dynamic>? outputData,
    List<AdvancedAgentFailure>? failures,
    String? executionLog,
    Duration? executionDuration,
    String? locale,
    DateTime? completedAt,
  }) =>
      AdvancedAgentResult(
        resultId: resultId ?? this.resultId,
        status: status ?? this.status,
        planId: planId ?? this.planId,
        requestId: requestId ?? this.requestId,
        outputData: outputData ?? this.outputData,
        failures: failures ?? this.failures,
        executionLog: executionLog ?? this.executionLog,
        executionDuration: executionDuration ?? this.executionDuration,
        locale: locale ?? this.locale,
        completedAt: completedAt ?? this.completedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedAgentResult && resultId == other.resultId;

  @override
  int get hashCode => resultId.hashCode;

  @override
  String toString() =>
      'AdvancedAgentResult(id: $resultId, status: $status, '
      'plan: $planId, failures: ${failures.length})';
}
