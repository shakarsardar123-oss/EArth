/// recovery_coordinator.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Application-layer coordinator that orchestrates the full
/// recovery pipeline: classify → analyze → strategize → replan → retry.
///
/// Clean architecture: Application layer, depends on Domain services.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import '../domain/models/agent_plan.dart';
import '../domain/models/recovery_context.dart';
import '../domain/models/recovery_failure.dart';
import '../domain/models/recovery_phase.dart';
import '../domain/models/recovery_state.dart';
import '../domain/services/recovery_executor.dart';
import '../domain/services/recovery_failure_classifier.dart';
import '../domain/services/replanning_engine.dart';
import '../../../core/errors/result.dart';

/// Callback for state changes during recovery coordination.
typedef RecoveryStateCallback = void Function(RecoveryState state);

/// Application-layer coordinator for agent recovery.
///
/// Orchestrates the full recovery pipeline:
/// 1. Receives a failure from step execution
/// 2. Classifies the failure
/// 3. Analyzes the failure context
/// 4. Determines the recovery strategy
/// 5. Executes the strategy (retry/replan/abort)
/// 6. Reports state changes through callbacks
///
/// Respects cancellation at every step.
class RecoveryCoordinator {
  final RecoveryFailureClassifier _classifier;
  final ReplanningEngine _replanningEngine;
  final RecoveryExecutor _executor;

  RecoveryState _state;
  final List<RecoveryStateCallback> _stateCallbacks = [];

  RecoveryCoordinator({
    required RecoveryFailureClassifier classifier,
    required ReplanningEngine replanningEngine,
    required RecoveryExecutor executor,
    RecoveryState initialState = const RecoveryState(),
  })  : _classifier = classifier,
        _replanningEngine = replanningEngine,
        _executor = executor,
        _state = initialState;

  /// Current recovery state.
  RecoveryState get state => _state;

  /// Register a callback for state changes.
  void addStateCallback(RecoveryStateCallback callback) {
    _stateCallbacks.add(callback);
  }

  /// Remove a state change callback.
  void removeStateCallback(RecoveryStateCallback callback) {
    _stateCallbacks.remove(callback);
  }

  void _notifyStateChange() {
    for (final callback in _stateCallbacks) {
      callback(_state);
    }
  }

  void _updateState(RecoveryState newState) {
    _state = newState;
    _notifyStateChange();
  }

  /// Start recovery for a failed step.
  ///
  /// This is the main entry point. Call when a step fails during
  /// plan execution. The coordinator will:
  /// 1. Transition to [RecoveryPhase.analyzingFailure]
  /// 2. Classify and analyze the failure
  /// 3. Determine strategy
  /// 4. Execute recovery (retry/replan/abort)
  ///
  /// Returns the final [RecoveryResult] — either a new plan
  /// to continue executing, or a failure if recovery failed.
  RecoveryResult<AgentPlan> recover(
    RecoveryContext context,
    Object rawError, {
    dynamic action,
  }) {
    // Check cancellation first
    if (_state.isCancellationRequested || _executor.isCancelled) {
      _updateState(_state.copyWith(
        phase: RecoveryPhase.cancelled,
        lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return Result.failure(RecoveryFailure.cancellation(
        'Recovery cancelled by user',
      ));
    }

    // Phase 1: Classify failure
    _updateState(_state.copyWith(
      phase: RecoveryPhase.analyzingFailure,
      lastFailure: context.failure,
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    final classifiedFailure = _classifier.classify(rawError, action: action);

    // Phase 2: Analyze failure
    final analyzedContext = _replanningEngine.recordFailedStep(
      context,
      context.failedStep!,
      classifiedFailure,
    );
    final deepAnalyzed = _replanningEngine.analyzeFailure(analyzedContext);

    // Phase 3: Determine strategy
    final strategy = _replanningEngine.determineRecoveryStrategy(
      deepAnalyzed,
    );

    final strategyContext = deepAnalyzed.copyWith(
      strategy: strategy,
    );

    // Phase 4: Check if we can recover
    if (!_replanningEngine.canReplan(strategyContext)) {
      _updateState(_state.copyWith(
        phase: RecoveryPhase.aborted,
        lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return Result.failure(RecoveryFailure.unsupportedAction(
        'Recovery not possible: retries exhausted or strategy is abort',
      ));
    }

    // Phase 5: Execute strategy
    _updateState(_state.copyWith(
      phase: RecoveryPhase.recovering,
      context: strategyContext,
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    _executor.injectRecoveryContext(strategyContext, RecoveryPhase.recovering);

    switch (strategy) {
      case RecoveryStrategy.retrySame:
      case RecoveryStrategy.retryModified:
      case RecoveryStrategy.waitAndRetry:
        return _handleRetry(strategyContext, strategy);

      case RecoveryStrategy.recaptureScreen:
      case RecoveryStrategy.reunderstandScreen:
      case RecoveryStrategy.researchTarget:
        return _handleScreenRecovery(strategyContext, strategy);

      case RecoveryStrategy.replan:
        return _handleReplan(strategyContext);

      case RecoveryStrategy.requestPermission:
        return _handlePermissionRequest(strategyContext);

      case RecoveryStrategy.skipStep:
        return _handleSkipStep(strategyContext);

      case RecoveryStrategy.abortSafely:
        _updateState(_state.copyWith(
          phase: RecoveryPhase.aborted,
          lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
        ));
        return Result.failure(RecoveryFailure.unsupportedAction(
          'Agent aborted safely after failure',
        ));
    }
  }

  RecoveryResult<AgentPlan> _handleRetry(
    RecoveryContext context,
    RecoveryStrategy strategy,
  ) {
    _updateState(_state.copyWith(
      phase: RecoveryPhase.retrying,
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    final step = context.failedStep;
    if (step == null) {
      return Result.failure(RecoveryFailure.invalidParameters(
        'Cannot retry: no failed step in context',
      ));
    }

    final result = _executor.executeStep(step, context);
    if (result.isSuccess) {
      _updateState(_state.copyWith(
        phase: RecoveryPhase.succeeded,
        lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return Result.success(context.currentPlan);
    }

    return Result.failure(result.failureOrNull!);
  }

  RecoveryResult<AgentPlan> _handleScreenRecovery(
    RecoveryContext context,
    RecoveryStrategy strategy,
  ) {
    _updateState(_state.copyWith(
      phase: RecoveryPhase.recovering,
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    // For screen-based recovery, replan with fresh screen context
    return _handleReplan(context);
  }

  RecoveryResult<AgentPlan> _handleReplan(RecoveryContext context) {
    _updateState(_state.copyWith(
      phase: RecoveryPhase.replanning,
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    final replanResult = _replanningEngine.generateAlternativePlan(context);
    if (replanResult.isSuccess) {
      _updateState(_state.copyWith(
        currentPlan: replanResult.valueOrNull,
        lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return Result.success(replanResult.valueOrNull!);
    }

    return Result.failure(replanResult.failureOrNull!);
  }

  RecoveryResult<AgentPlan> _handlePermissionRequest(
    RecoveryContext context,
  ) {
    // Permission recovery delegates to the executor layer
    _executor.injectRecoveryContext(
      context,
      RecoveryPhase.recovering,
    );
    return Result.failure(RecoveryFailure.permissionFailure(
      'Permission required — awaiting user action',
      action: context.failedStep,
    ));
  }

  RecoveryResult<AgentPlan> _handleSkipStep(RecoveryContext context) {
    final plan = context.currentPlan;
    final nextIndex = plan.currentStepIndex + 1;
    final updatedPlan = plan.copyWith(currentStepIndex: nextIndex);

    _updateState(_state.copyWith(
      phase: RecoveryPhase.succeeded,
      currentPlan: updatedPlan,
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    return Result.success(updatedPlan);
  }

  /// Cancel all recovery operations.
  void cancelRecovery() {
    _executor.cancel();
    _updateState(_state.copyWith(
      phase: RecoveryPhase.cancelled,
      retryPolicy: _state.retryPolicy.cancel(),
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Reset the coordinator to idle state.
  void reset() {
    _updateState(const RecoveryState(
      phase: RecoveryPhase.idle,
      lastUpdatedTimestamp: 0,
    ));
  }
}
