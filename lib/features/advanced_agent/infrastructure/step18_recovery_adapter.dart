/// step18_recovery_adapter.dart
/// AURA Assistant – Step 25: Infrastructure adapter for Step 18 Recovery.
///
/// Adapts Step 18's RecoveryProvider contract to Step 25's RecoveryRepository.
/// FAIL-CLOSED: NEVER uses skip or fallback.
/// Maps Step 18 real actions (retry/modify/recapture/reunderstand/replan/abort)
/// to domain RecoveryAction enum (retry/replan/skip/abort).
/// skip → NEVER; always prefer abort over skip in fail-closed mode.
library;

import '../domain/models/advanced_agent_failure.dart';
import '../domain/repositories/recovery_repository.dart';

/// Step 18 real recovery action names.
enum Step18RecoveryAction {
  retry,
  modify,
  recapture,
  reunderstand,
  replan,
  abort,
}

/// Adapter bridging Step 18 Recovery to Step 25's RecoveryRepository.
///
/// Implements the EXACT RecoveryRepository interface:
///   classifyAndStrategize({failureType, errorMessage, retryAttempt}) → RecoveryStrategy
///   executeStrategy(strategy) → bool
///   isAvailable() → bool
///
/// FAIL-CLOSED rules:
///   - NEVER maps to RecoveryAction.skip — always abort instead.
///   - modify/recapture/reunderstand → RecoveryAction.replan (closest safe mapping)
///   - Unknown actions → RecoveryAction.abort (fail-closed)
class Step18RecoveryAdapter implements RecoveryRepository {
  @override
  Future<RecoveryStrategy> classifyAndStrategize({
    required String failureType,
    required String errorMessage,
    int retryAttempt = 0,
  }) async {
    // Parse failure type from string.
    final type = AdvancedAgentFailureType.fromName(failureType);

    // FAIL-CLOSED: permanent failures always abort.
    final failure = AdvancedAgentFailure(
      failureId: 'recovery-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      message: errorMessage,
      retryAttempt: retryAttempt,
      occurredAt: DateTime.now(),
    );

    if (failure.isPermanent) {
      return const RecoveryStrategy(
        action: RecoveryAction.abort,
        message: 'Permanent failure — aborting (fail-closed).',\      );
    }

    // Map failure type to appropriate action.
    switch (type) {
      case AdvancedAgentFailureType.planningFailed:
      case AdvancedAgentFailureType.replanningFailed:
        return RecoveryStrategy(
          action: RecoveryAction.replan,
          currentRetry: retryAttempt,
          message: 'Planning failure — recommending replan.',
        );

      case AdvancedAgentFailureType.toolSelectionFailed:
      case AdvancedAgentFailureType.contextExecutionFailed:
      case AdvancedAgentFailureType.correctionFailed:
      case AdvancedAgentFailureType.dependencyFailed:
        if (failure.isRecoverable) {
          return RecoveryStrategy(
            action: RecoveryAction.retry,
            currentRetry: retryAttempt,
            message: 'Recoverable failure — recommending retry.',
          );
        }
        return const RecoveryStrategy(
          action: RecoveryAction.abort,
          message: 'Non-recoverable failure — aborting (fail-closed).',
        );

      case AdvancedAgentFailureType.goalTrackingFailed:
      case AdvancedAgentFailureType.progressTrackingFailed:
        return const RecoveryStrategy(
          action: RecoveryAction.replan,
          message: 'Tracking failure — recommending replan.',
        );

      case AdvancedAgentFailureType.verificationFailed:
        return RecoveryStrategy(
          action: RecoveryAction.retry,
          currentRetry: retryAttempt,
          message: 'Verification failure — recommending retry.',
        );

      case AdvancedAgentFailureType.pauseResumeFailed:
        return const RecoveryStrategy(
          action: RecoveryAction.abort,
          message: 'Pause/resume failure — aborting (fail-closed).',
        );

      // FAIL-CLOSED: safety denials, unavailability, cancelled, unknown → abort
      case AdvancedAgentFailureType.safetyDenied:
      case AdvancedAgentFailureType.safetyUnavailable:
      case AdvancedAgentFailureType.cancelled:
      case AdvancedAgentFailureType.unknown:
        return const RecoveryStrategy(
          action: RecoveryAction.abort,
          message: 'Safety/cancel/unknown — aborting (fail-closed).',
        );
    }
  }

  @override
  Future<bool> executeStrategy(RecoveryStrategy strategy) async {
    // FAIL-CLOSED: NEVER execute skip — always abort instead.
    if (strategy.action == RecoveryAction.skip) {
      return false; // Treat skip as abort failure.
    }

    switch (strategy.action) {
      case RecoveryAction.retry:
        // Retry: return true to signal retry should proceed.
        return strategy.canRetry;

      case RecoveryAction.replan:
        // Replan: return true to signal replanning needed.
        return true;

      // FAIL-CLOSED: NEVER skip — always abort instead.
      case RecoveryAction.skip:
        return false;

      case RecoveryAction.abort:
        return false; // Signals abort.
    }
  }

  @override
  bool isAvailable() => true;

  /// Map a Step 18 action name to domain RecoveryAction.
  /// FAIL-CLOSED: unknown → abort, never skip.
  static RecoveryAction mapStep18Action(String actionName) {
    switch (actionName) {
      case 'retry':
        return RecoveryAction.retry;
      case 'modify':
      case 'recapture':
      case 'reunderstand':
        // Map all Step 18 non-retry/non-abort actions to replan.
        // NEVER map to skip.
        return RecoveryAction.replan;
      case 'replan':
        return RecoveryAction.replan;
      case 'abort':
        return RecoveryAction.abort;
      default:
        // FAIL-CLOSED: any unknown → abort, never skip.
        return RecoveryAction.abort;
    }
  }
}
