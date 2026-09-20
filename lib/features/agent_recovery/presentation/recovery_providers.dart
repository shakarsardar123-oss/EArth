/// recovery_providers.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Riverpod providers for the agent recovery feature.
/// Follows the MemoryProviderNames pattern from Step 17:
///   - Abstract class with static const String name + Type type constants
///   - Type aliases
///   - Concrete `final` provider instances with `name:` keyword parameter
///   - StateNotifierProvider for state, Provider for services
///
/// Clean architecture: Presentation layer.
///
/// Kurdish-first, local-first, privacy-conscious.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/agent_plan.dart';
import '../domain/models/recovery_context.dart';
import '../domain/models/recovery_failure.dart';
import '../domain/models/recovery_failure_phase.dart';
import '../domain/models/recovery_phase.dart';
import '../domain/models/recovery_state.dart';
import '../domain/models/retry_policy.dart';
import '../domain/services/recovery_executor.dart';
import '../domain/services/recovery_failure_classifier.dart';
import '../domain/services/replanning_engine.dart';
import '../application/recovery_coordinator.dart';
import '../infrastructure/default_recovery_failure_classifier.dart';
import '../infrastructure/default_recovery_executor.dart';
import '../infrastructure/default_replanning_engine.dart';

/// Provider names for the agent recovery feature.
///
/// Follows the MemoryProviderNames pattern:
/// - abstract class with static const String name constants
/// - static const Type type constants for each provider
abstract class RecoveryProviderNames {
  // ─── Name constants ──────────────────────────────────────────────

  static const String recoveryState = 'recoveryState';
  static const String recoveryCoordinator = 'recoveryCoordinator';
  static const String retryPolicy = 'retryPolicy';
  static const String recoveryFailureClassifier =
      'recoveryFailureClassifier';
  static const String replanningEngine = 'replanningEngine';
  static const String recoveryExecutor = 'recoveryExecutor';
  static const String recoveryContext = 'recoveryContext';
  static const String agentPlan = 'agentPlan';

  // ─── Type constants ──────────────────────────────────────────────

  static const Type recoveryStateType = RecoveryStateNotifier;
  static const Type recoveryCoordinatorType = RecoveryCoordinator;
  static const Type retryPolicyType = RetryPolicy;
  static const Type recoveryFailureClassifierType =
      DefaultRecoveryFailureClassifier;
  static const Type replanningEngineType = DefaultReplanningEngine;
  static const Type recoveryExecutorType = DefaultRecoveryExecutor;
  static const Type recoveryContextType = RecoveryContext;
  static const Type agentPlanType = AgentPlan;
}

// ─── Type aliases ──────────────────────────────────────────────────

typedef RecoveryStateProvider
    = StateNotifierProvider<RecoveryStateNotifier, RecoveryState>;

// ─── StateNotifier ─────────────────────────────────────────────────

/// StateNotifier for recovery state management.
///
/// Manages the recovery lifecycle and exposes state changes
/// through Riverpod's StateNotifier pattern.
class RecoveryStateNotifier extends StateNotifier<RecoveryState> {
  RecoveryCoordinator? _coordinator;

  RecoveryStateNotifier() : super(const RecoveryState());

  /// Initialize the coordinator with dependencies.
  void initialize() {
    const classifier = DefaultRecoveryFailureClassifier();
    final executor = DefaultRecoveryExecutor();
    const engine = DefaultReplanningEngine(classifier: classifier);

    _coordinator = RecoveryCoordinator(
      classifier: classifier,
      replanningEngine: engine,
      executor: executor,
      initialState: state,
    );

    _coordinator!.addStateCallback(_onStateChanged);
  }

  void _onStateChanged(RecoveryState newState) {
    state = newState;
  }

  /// Start recovery for a failed step.
  ///
  /// Returns the recovery result (new plan or failure).
  RecoveryResult<AgentPlan>? recover(
    RecoveryContext context,
    Object rawError, {
    dynamic action,
  }) {
    if (_coordinator == null) initialize();
    return _coordinator!.recover(context, rawError, action: action);
  }

  /// Cancel all recovery operations.
  void cancelRecovery() {
    _coordinator?.cancelRecovery();
  }

  /// Reset to idle state.
  void reset() {
    _coordinator?.reset();
  }

  /// Update the retry policy.
  void updateRetryPolicy(RetryPolicy policy) {
    state = state.copyWith(retryPolicy: policy);
  }

  /// Set the current agent plan.
  void setAgentPlan(AgentPlan plan) {
    state = state.copyWith(
      currentPlan: plan,
      originalPlan: state.originalPlan ?? plan,
      remainingStepCount: plan.remainingSteps.length,
      completedStepCount: plan.successfulStepCount,
    );
  }

  /// Record a step completion.
  void recordStepCompletion(AgentStepResult result) {
    state = state.copyWith(
      completedStepCount:
          state.completedStepCount + (result.succeeded ? 1 : 0),
      lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Check if recovery is possible for the given failure.
  bool canRecover(RecoveryFailure failure) {
    if (state.isCancellationRequested) return false;
    if (state.hasRetriesExhausted) return false;
    return state.retryPolicy.isRetryable(failure.phase);
  }
}

// ─── Concrete providers ────────────────────────────────────────────

/// Recovery failure classifier provider (default infrastructure impl).
final recoveryFailureClassifierProvider =
    Provider<RecoveryFailureClassifier>(
  (ref) => const DefaultRecoveryFailureClassifier(),
  name: RecoveryProviderNames.recoveryFailureClassifier,
);

/// Recovery executor provider (default infrastructure impl).
final recoveryExecutorProvider = Provider<RecoveryExecutor>(
  (ref) => DefaultRecoveryExecutor(),
  name: RecoveryProviderNames.recoveryExecutor,
);

/// Replanning engine provider (default infrastructure impl).
final replanningEngineProvider = Provider<ReplanningEngine>(
  (ref) => DefaultReplanningEngine(
    classifier: ref.watch(recoveryFailureClassifierProvider),
  ),
  name: RecoveryProviderNames.replanningEngine,
);

/// Retry policy provider.
final retryPolicyProvider = Provider<RetryPolicy>(
  (ref) => const RetryPolicy(),
  name: RecoveryProviderNames.retryPolicy,
);

/// Recovery coordinator provider (application service).
final recoveryCoordinatorProvider = Provider<RecoveryCoordinator>(
  (ref) => RecoveryCoordinator(
    classifier: ref.watch(recoveryFailureClassifierProvider),
    replanningEngine: ref.watch(replanningEngineProvider),
    executor: ref.watch(recoveryExecutorProvider),
  ),
  name: RecoveryProviderNames.recoveryCoordinator,
);

/// Recovery context provider (default empty context placeholder).
final recoveryContextProvider = Provider<RecoveryContext?>(
  (ref) => null,
  name: RecoveryProviderNames.recoveryContext,
);

/// Agent plan provider (default null — set via StateNotifier).
final agentPlanProvider = Provider<AgentPlan?>(
  (ref) => ref.watch(recoveryStateProvider).currentPlan,
  name: RecoveryProviderNames.agentPlan,
);

/// Recovery state notifier provider.
final recoveryStateProvider =
    StateNotifierProvider<RecoveryStateNotifier, RecoveryState>(
  (ref) => RecoveryStateNotifier(),
  name: RecoveryProviderNames.recoveryState,
);
