/// Step 23 — Recovery Adapter (WIRED for classification; strategy execution
/// is delegated back to the orchestrator phase machine — see note below).
///
/// Implements [RecoveryRepository] by delegating failure classification and
/// strategy selection to the real Step 18 [AgentRecovery.decide]. It creates
/// NO second recovery engine.
///
/// Type conversion happens ONLY at this boundary:
///   (failureType, errorMessage, retryAttempt) → a lightweight AgentStep +
///     AgentContext that carry the real failure info into AgentRecovery;
///   core [RecoveryStrategy] enum → domain [RecoveryAction].
///
/// NOTE on [executeStrategy]: AgentRecovery is a *decision* module — it does
/// not itself re-run tools (re-execution is driven by the orchestrator's
/// executing/planning phases). So [executeStrategy] does not fabricate a
/// success; it reports whether the chosen strategy is actionable (retryable
/// and not abort). The orchestrator then performs the actual retry/replan.
///
/// FAIL-CLOSED: unknown/exhausted → abort; error → abort; non-actionable
/// strategy → false.

import '../../../../core/agent/agent_recovery.dart' as core;
import '../../../../core/agent/agent_context.dart';
import '../../../../core/agent/agent_step.dart';
import '../../../../domain/entities/agent_config.dart';
import '../../domain/orchestration_domain.dart';

class RecoveryAdapter implements RecoveryRepository {
  /// The real Step 18 recovery decision module (injected).
  final core.AgentRecovery _recovery;

  RecoveryAdapter(this._recovery);

  /// Map the core [core.RecoveryStrategy] enum to the domain [RecoveryAction].
  RecoveryAction _toAction(core.RecoveryStrategy strategy) {
    switch (strategy) {
      case core.RecoveryStrategy.retry:
        return RecoveryAction.retry;
      case core.RecoveryStrategy.retryWithModification:
        return RecoveryAction.modify;
      case core.RecoveryStrategy.skip:
        // No direct 'skip' in the domain contract; the closest safe action
        // is to re-plan around the failed step.
        return RecoveryAction.replan;
      case core.RecoveryStrategy.replan:
        return RecoveryAction.replan;
      case core.RecoveryStrategy.abort:
        return RecoveryAction.abort;
    }
  }

  @override
  Future<RecoveryStrategy> classifyAndStrategize({
    required String failureType,
    required String errorMessage,
    required int retryAttempt,
  }) async {
    try {
      // Carry the real failure info into AgentRecovery via lightweight,
      // genuine domain objects (not fabricated success state).
      final step = AgentStep(
        toolName: failureType,
        parameters: const {},
        retryCount: retryAttempt,
      )..error = errorMessage;

      final context = AgentContext(
        agentConfig: AgentConfig.defaultConfig,
        retryCount: retryAttempt,
      );

      final decision = _recovery.decide(step, context, null);
      final action = _toAction(decision.strategy);

      if (action == RecoveryAction.abort) {
        return RecoveryStrategy.abort(reason: decision.reason);
      }

      return RecoveryStrategy(
        action: action,
        modifiedParameters: decision.modifiedArguments?.toString(),
        maxRetries: core.AgentRecovery.globalMaxRetries,
        currentAttempt: retryAttempt,
        reason: decision.reason,
      );
    } catch (e) {
      // FAIL-CLOSED: error → abort.
      return RecoveryStrategy.abort(reason: 'Recovery classification error: $e');
    }
  }

  @override
  Future<bool> executeStrategy(RecoveryStrategy strategy) async {
    try {
      // AgentRecovery does not execute strategies; the orchestrator drives
      // the actual retry/replan. Report whether the strategy is actionable.
      return strategy.action != RecoveryAction.abort && strategy.canRetry;
    } catch (_) {
      // FAIL-CLOSED: error → not recovered.
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async => true;
}
