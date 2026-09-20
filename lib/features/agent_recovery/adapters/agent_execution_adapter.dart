/// agent_execution_adapter.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Adapter bridging the agent execution flow to the recovery subsystem.
/// Follows the MemoryToolDef/MemoryToolParam pattern from Step 17:
///   - AgentToolResult / AgentToolParam / AgentToolDef helper classes
///   - Abstract AgentExecutionAdapter with static tool name constants
///     + definitions + abstract execute()
///   - Concrete AgentExecutionAdapterImpl wiring to RecoveryCoordinator
///     with switch dispatch
///
/// Tools: injectRecoveryContext, cancelRecovery, checkRetryPolicy,
///        recover, getRecoveryState
///
/// Clean architecture: Infrastructure layer (adapter).
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:meta/meta.dart';

import '../domain/models/agent_plan.dart';
import '../domain/models/recovery_context.dart';
import '../domain/models/recovery_failure.dart';
import '../domain/models/recovery_state.dart';
import '../domain/models/retry_policy.dart';
import '../application/recovery_coordinator.dart';
import '../../../core/errors/result.dart';

// ─── Helper classes ────────────────────────────────────────────────

/// Result type returned by agent execution adapter tool calls.
@immutable
class AgentToolResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  const AgentToolResult({
    required this.success,
    required this.message,
    this.data,
  });

  AgentToolResult copyWith({
    bool? success,
    String? message,
    Map<String, dynamic>? data,
  }) =>
      AgentToolResult(
        success: success ?? this.success,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentToolResult &&
          success == other.success &&
          message == other.message;

  @override
  int get hashCode => Object.hash(success, message);
}

/// Parameter type for agent execution adapter tool calls.
@immutable
class AgentToolParam {
  final String name;
  final String type;
  final String description;
  final bool required;
  final dynamic defaultValue;

  const AgentToolParam({
    required this.name,
    required this.type,
    required this.description,
    this.required = true,
    this.defaultValue,
  });
}

/// Tool definition for agent execution adapter.
@immutable
class AgentToolDef {
  final String name;
  final String description;
  final List<AgentToolParam> parameters;

  const AgentToolDef({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

// ─── Abstract adapter ──────────────────────────────────────────────

/// Abstract base class for the agent execution adapter.
///
/// Provides static tool name constants, tool definitions, and
/// the abstract execute() method. Mirrors the MemoryAdapter
/// pattern from Step 17.
abstract class AgentExecutionAdapter {
  // ─── Tool name constants ────────────────────────────────────────

  static const String injectRecoveryContext = 'injectRecoveryContext';
  static const String cancelRecovery = 'cancelRecovery';
  static const String checkRetryPolicy = 'checkRetryPolicy';
  static const String recover = 'recover';
  static const String getRecoveryState = 'getRecoveryState';

  // ─── Tool definitions ──────────────────────────────────────────

  static List<AgentToolDef> get allDefinitions => [
        const AgentToolDef(
          name: injectRecoveryContext,
          description:
              'Inject a recovery context into the recovery subsystem. '
              'Used when the agent encounters an error and needs to '
              'provide context for recovery.',
          parameters: [
            AgentToolParam(
              name: 'context',
              type: 'RecoveryContext',
              description:
                  'The recovery context containing error details, '
                  'step information, and screen metadata.',
              required: true,
            ),
          ],
        ),
        const AgentToolDef(
          name: cancelRecovery,
          description:
              'Cancel all ongoing recovery operations. '
              'Triggers graceful shutdown of retry/replanning cycles.',
          parameters: [],
        ),
        const AgentToolDef(
          name: checkRetryPolicy,
          description:
              'Check whether a given failure phase is retryable '
              'under the current retry policy.',
          parameters: [
            AgentToolParam(
              name: 'phase',
              type: 'RecoveryFailurePhase',
              description:
                  'The failure phase to check against the retry policy.',
              required: true,
            ),
          ],
        ),
        const AgentToolDef(
          name: recover,
          description:
              'Start the recovery process for a failed step. '
              'The recovery coordinator will classify the failure, '
              'select a strategy, and either retry or replan.',
          parameters: [
            AgentToolParam(
              name: 'context',
              type: 'RecoveryContext',
              description: 'Recovery context for the failed step.',
              required: true,
            ),
            AgentToolParam(
              name: 'rawError',
              type: 'Object',
              description: 'The raw error that triggered recovery.',
              required: true,
            ),
            AgentToolParam(
              name: 'action',
              type: 'dynamic',
              description: 'Optional action hint for the recovery strategy.',
              required: false,
            ),
          ],
        ),
        const AgentToolDef(
          name: getRecoveryState,
          description:
              'Retrieve the current recovery state including '
              'phase, retry counts, and active strategy.',
          parameters: [],
        ),
      ];

  // ─── Abstract execute ───────────────────────────────────────────

  /// Execute a tool call by name with the given parameters.
  ///
  /// Returns [AgentToolResult] with success/failure status and data.
  /// Throws [ArgumentError] for unknown tool names.
  AgentToolResult execute(
    String toolName,
    Map<String, dynamic> arguments,
  );
}

// ─── Concrete implementation ──────────────────────────────────────

/// Concrete implementation wiring to RecoveryCoordinator.
///
/// Dispatches tool calls via switch on the tool name constant,
/// delegating to the RecoveryCoordinator application service.
@immutable
class AgentExecutionAdapterImpl extends AgentExecutionAdapter {
  final RecoveryCoordinator _coordinator;

  const AgentExecutionAdapterImpl({
    required RecoveryCoordinator coordinator,
  }) : _coordinator = coordinator;

  @override
  AgentToolResult execute(
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    switch (toolName) {
      case AgentExecutionAdapter.injectRecoveryContext:
        return _injectRecoveryContext(arguments);

      case AgentExecutionAdapter.cancelRecovery:
        return _cancelRecovery();

      case AgentExecutionAdapter.checkRetryPolicy:
        return _checkRetryPolicy(arguments);

      case AgentExecutionAdapter.recover:
        return _recover(arguments);

      case AgentExecutionAdapter.getRecoveryState:
        return _getRecoveryState();

      default:
        throw ArgumentError(
          'Unknown AgentExecutionAdapter tool: $toolName',
        );
    }
  }

  // ─── Private dispatch methods ──────────────────────────────────

  AgentToolResult _injectRecoveryContext(Map<String, dynamic> arguments) {
    final context = arguments['context'];
    if (context is! RecoveryContext) {
      return const AgentToolResult(
        success: false,
        message: 'Invalid or missing RecoveryContext argument.',
      );
    }

    _coordinator.injectContext(context);
    return AgentToolResult(
      success: true,
      message: 'Recovery context injected successfully.',
      data: {
        'stepIndex': context.stepIndex,
        'errorTimestamp': context.errorTimestamp,
      },
    );
  }

  AgentToolResult _cancelRecovery() {
    _coordinator.cancelRecovery();
    return const AgentToolResult(
      success: true,
      message: 'Recovery cancellation requested.',
    );
  }

  AgentToolResult _checkRetryPolicy(Map<String, dynamic> arguments) {
    final phase = arguments['phase'];
    if (phase is! RecoveryFailurePhase) {
      return const AgentToolResult(
        success: false,
        message: 'Invalid or missing RecoveryFailurePhase argument.',
      );
    }

    final policy = _coordinator.currentRetryPolicy;
    final retryable = policy.isRetryable(phase);
    return AgentToolResult(
      success: true,
      message: retryable
          ? 'Phase $phase is retryable under current policy.'
          : 'Phase $phase is NOT retryable under current policy.',
      data: {'retryable': retryable, 'phase': phase.name},
    );
  }

  AgentToolResult _recover(Map<String, dynamic> arguments) {
    final context = arguments['context'];
    final rawError = arguments['rawError'];
    final action = arguments['action'];

    if (context is! RecoveryContext) {
      return const AgentToolResult(
        success: false,
        message: 'Invalid or missing RecoveryContext argument.',
      );
    }

    final result = _coordinator.recover(
      context,
      rawError ?? Exception('Unknown error'),
      action: action,
    );

    return result.isSuccess
        ? AgentToolResult(
            success: true,
            message: 'Recovery succeeded. New plan available.',
            data: {
              'planRemainingSteps':
                  result.valueOrNull?.remainingSteps.length ?? 0,
            },
          )
        : AgentToolResult(
            success: false,
            message:
                'Recovery failed: ${result.failureOrNull?.message ?? "unknown"}',
            data: {
              'failurePhase': result.failureOrNull?.phase.name ?? 'unknown',
            },
          );
  }

  AgentToolResult _getRecoveryState() {
    final state = _coordinator.currentState;
    return AgentToolResult(
      success: true,
      message: 'Current recovery state retrieved.',
      data: {
        'phase': state.phase.name,
        'currentRetryCount': state.currentRetryCount,
        'hasRetriesExhausted': state.hasRetriesExhausted,
        'isCancellationRequested': state.isCancellationRequested,
        'currentStrategy': state.currentStrategy?.name ?? 'none',
      },
    );
  }
}
