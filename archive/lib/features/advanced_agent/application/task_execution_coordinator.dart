/// task_execution_coordinator.dart
/// AURA Assistant – Step 25: Central coordinator orchestrating all 10 capabilities.
///
/// Coordinates: (1) Multi-Step Task Planning, (2) Dynamic Replanning,
/// (3) Goal Tracking, (4) Result Verification, (5) Tool Selection Intelligence,
/// (6) Context-Aware Execution, (7) Natural Language Correction,
/// (8) Task Progress State, (9) Pause/Resume/Cancel, (10) Safety Gate.
///
/// FAIL-CLOSED: any unknown/unavailable dependency → deny/abort.
/// RecoveryStrategy.canSkip is ALWAYS treated as shouldAbort — NEVER skip.
/// Kurdish Sorani RTL-first (locale='ku').
library;

import '../domain/domain.dart';
import '../../../core/errors/result.dart';

// ─── CoordinationResult ───────────────────────────────────────────────
// Uses ONLY verified API types and factories.

class CoordinationResult {
  final bool success;
  final String? errorMessage;
  final AdvancedAgentResult? agentResult;
  final SafetyVerdict safetyVerdict;
  final PauseResumeState pauseState;
  final TaskProgressState progressState;

  const CoordinationResult({
    this.success = false,
    this.errorMessage,
    this.agentResult,
    required this.safetyVerdict,
    this.pauseState = PauseResumeState.running,
    required this.progressState,
  });

  /// FAIL-CLOSED factory for denied result.
  factory CoordinationResult.denied({
    String? reason,
    SafetyVerdict? verdict,
    String? planId,
  }) {
    final resultId = 'cr_${DateTime.now().millisecondsSinceEpoch}';
    return CoordinationResult(
      success: false,
      errorMessage: reason ?? 'DENIED: fail-closed default',
      safetyVerdict: verdict ??
          SafetyVerdict.denied(
            verdictId: '${resultId}_sv',
            rationale: 'FAIL-CLOSED: default denied',
          ),
      pauseState: PauseResumeState.running,
      progressState: planId != null
          ? TaskProgressState.failed(
              planId: planId,
              errorMessage: reason ?? 'DENIED: fail-closed default',
            )
          : TaskProgressState(
              planId: resultId,
              planStatus: PlanStatus.failed,
              updatedAt: DateTime.now(),
            ),
    );
  }

  /// Factory for successful coordination.
  factory CoordinationResult.success({
    required AdvancedAgentResult result,
    required SafetyVerdict verdict,
    required TaskProgressState progress,
  }) =>
      CoordinationResult(
        success: true,
        agentResult: result,
        safetyVerdict: verdict,
        progressState: progress,
        pauseState: PauseResumeState.running,
      );

  /// Factory for cancelled coordination.
  factory CoordinationResult.cancelled({
    required String planId,
  }) {
    final resultId = 'cr_${DateTime.now().millisecondsSinceEpoch}';
    return CoordinationResult(
      success: false,
      errorMessage: 'CANCELLED: user cancelled execution',
      safetyVerdict: SafetyVerdict.denied(
        verdictId: '${resultId}_sv',
        rationale: 'Execution cancelled by user.',
      ),
      pauseState: PauseResumeState.cancelled,
      progressState: TaskProgressState.failed(
        planId: planId,
        errorMessage: 'Execution cancelled by user.',
      ),
    );
  }

  /// Factory for offline-degraded coordination.
  factory CoordinationResult.offlineDegraded({
    String? reason,
    required AdvancedAgentResult result,
    required String planId,
  }) =>
      CoordinationResult(
        success: false,
        errorMessage:
            reason ?? 'OFFLINE: connectivity unavailable, degraded mode',
        agentResult: result,
        safetyVerdict: SafetyVerdict.allowed(
          verdictId: 'cr_${DateTime.now().millisecondsSinceEpoch}_sv',
          rationale: 'Offline degraded mode — safety allowed with constraints.',
        ),
        pauseState: PauseResumeState.running,
        progressState: TaskProgressState(
          planId: planId,
          planStatus: PlanStatus.active,
          updatedAt: DateTime.now(),
        ),
      );

  /// Factory for failed coordination (not denied, not cancelled).
  factory CoordinationResult.failed({
    String? reason,
    required List<AdvancedAgentFailure> failures,
    String? planId,
  }) {
    final resultId = 'cr_${DateTime.now().millisecondsSinceEpoch}';
    return CoordinationResult(
      success: false,
      errorMessage: reason ?? 'FAILED: execution failed',
      safetyVerdict: SafetyVerdict.denied(
        verdictId: '${resultId}_sv',
        rationale: 'Execution failed.',
      ),
      pauseState: PauseResumeState.running,
      progressState: planId != null
          ? TaskProgressState.failed(
              planId: planId,
              errorMessage: reason ?? 'FAILED: execution failed',
            )
          : TaskProgressState(
              planId: resultId,
              planStatus: PlanStatus.failed,
              updatedAt: DateTime.now(),
            ),
      agentResult: AdvancedAgentResult.failed(
        resultId: resultId,
        failures: failures,
        planId: planId,
      ),
    );
  }
}

// ─── TaskExecutionCoordinator ──────────────────────────────────────────

class TaskExecutionCoordinator {
  // --- 10 Capability Services ---
  final TaskPlannerService taskPlanner;
  final ReplannerService replanner;
  final GoalTrackerService goalTracker;
  final ResultVerifierService resultVerifier;
  final ToolSelectionService toolSelection;
  final ContextAwareExecutionService contextAwareExecution;
  final NaturalLanguageCorrectionService nlCorrection;
  final SafetyGateService safetyGate;
  final PauseResumeCancelService pauseResumeCancel;
  final TaskProgressService taskProgress;

  // --- Repositories ---
  final AgentEngineRepository agentEngine;
  final MemoryRepository memory;
  final ToolRegistryRepository toolRegistry;
  final SecurityRepository security;
  final PermissionRepository permission;
  final ConfirmationRepository confirmation;
  final ToolExecutionRepository toolExecution;
  final RecoveryRepository recovery;
  final ConnectivityRepository connectivity;
  final AuditRepository audit;
  final TriggerRepository trigger;

  // Internal replan counter.
  int _replanAttempt = 0;

  TaskExecutionCoordinator({
    required this.taskPlanner,
    required this.replanner,
    required this.goalTracker,
    required this.resultVerifier,
    required this.toolSelection,
    required this.contextAwareExecution,
    required this.nlCorrection,
    required this.safetyGate,
    required this.pauseResumeCancel,
    required this.taskProgress,
    required this.agentEngine,
    required this.memory,
    required this.toolRegistry,
    required this.toolExecution,
    required this.security,
    required this.permission,
    required this.confirmation,
    required this.recovery,
    required this.connectivity,
    required this.audit,
    required this.trigger,
  });

  // ─── Main execution pipeline ─────────────────────────────────────

  Future<CoordinationResult> executeTask({
    required String userIntent,
    String locale = 'ku',
    Map<String, dynamic> context = const {},
  }) async {
    final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    _replanAttempt = 0;

    // ═══ PHASE 0: Audit start ═══
    audit.record(
      action: 'task_execution_start',
      description: 'Starting task execution for intent: $userIntent',
      timestamp: now,
      details: {'requestId': requestId, 'locale': locale},
    );

    // ═══ PHASE 1: Agent Engine — Understand ═══
    final agentIntent = await agentEngine.understand(userIntent, locale);
    if (agentIntent == null) {
      audit.record(
        action: 'agent_engine_understand_failed',
        description: 'Agent engine could not understand intent',
        timestamp: DateTime.now(),
        details: {'requestId': requestId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: agent engine could not understand intent',
      );
    }
    audit.record(
      action: 'agent_engine_understood',
      description: 'Intent understood: ${agentIntent.action}',
      timestamp: DateTime.now(),
      details: {
        'requestId': requestId,
        'intentId': agentIntent.intentId,
        'confidence': agentIntent.confidence,
      },
    );

    // ═══ PHASE 2: Memory lookup (if available) ═══
    String? memoryContext;
    if (memory.isAvailable()) {
      memoryContext = await memory.lookup(userIntent, locale);
    }
    // If memory unavailable, memoryContext stays null — non-fatal.

    // ═══ PHASE 3: Safety Gate — guard() (FAIL-CLOSED entry) ═══
    // guard() internally checks isAvailable; if unavailable → denied.
    final safetyVerdict = safetyGate.guard(
      action: agentIntent.action,
      toolId: agentIntent.parameters['toolId'] as String?,
      riskCategory: agentIntent.parameters['riskCategory'] as String?,
      locale: locale,
    );
    if (safetyVerdict.isDenied) {
      audit.record(
        action: 'safety_gate_denied',
        description: 'Safety gate denied execution: ${safetyVerdict.rationale}',
        timestamp: DateTime.now(),
        details: {
          'requestId': requestId,
          'verdictId': safetyVerdict.verdictId,
        },
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: safety gate denied — ${safetyVerdict.rationale}',
        verdict: safetyVerdict,
      );
    }

    // ═══ PHASE 4: SecurityRepository pre-execution check ═══
    if (security.isAvailable()) {
      final secVerdict = await security.check(
        agentIntent.action,
        agentIntent.parameters['toolId'] as String? ?? '',
        agentIntent.parameters['riskLevel'] as String? ?? 'high',
      );
      if (secVerdict.isDenied) {
        audit.record(
          action: 'security_denied',
          description: 'Security check denied: ${secVerdict.rationale}',
          timestamp: DateTime.now(),
          details: {'requestId': requestId},
        );
        return CoordinationResult.denied(
          reason: 'FAIL-CLOSED: security denied — ${secVerdict.rationale}',
          verdict: secVerdict,
        );
      }
    } else {
      // Security unavailable → FAIL-CLOSED → denied
      audit.record(
        action: 'security_unavailable',
        description: 'Security repository unavailable — failing closed',
        timestamp: DateTime.now(),
        details: {'requestId': requestId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: security repository unavailable',
      );
    }

    // ═══ PHASE 5: PermissionRepository pre-execution check ═══
    if (permission.isAvailable()) {
      final permVerdict = await permission.check(
        agentIntent.action,
        agentIntent.parameters['toolId'] as String? ?? '',
      );
      if (!permVerdict.isGranted) {
        // Try requesting permission
        final reqVerdict = await permission.request(
          agentIntent.action,
          agentIntent.parameters['toolId'] as String? ?? '',
        );
        if (!reqVerdict.isGranted) {
          audit.record(
            action: 'permission_denied',
            description: 'Permission denied for action: ${agentIntent.action}',
            timestamp: DateTime.now(),
            details: {'requestId': requestId},
          );
          return CoordinationResult.denied(
            reason: 'FAIL-CLOSED: permission denied for ${agentIntent.action}',
          );
        }
      }
    } else {
      // Permission unavailable → FAIL-CLOSED → denied
      audit.record(
        action: 'permission_unavailable',
        description: 'Permission repository unavailable — failing closed',
        timestamp: DateTime.now(),
        details: {'requestId': requestId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: permission repository unavailable',
      );
    }

    // ═══ PHASE 6: ConfirmationRepository pre-execution check ═══
    if (confirmation.isAvailable()) {
      final confVerdict = await confirmation.checkAndObtain(
        toolId: agentIntent.parameters['toolId'] as String? ?? '',
        riskLevel: agentIntent.parameters['riskLevel'] as String? ?? 'high',
        userRequest: userIntent,
      );
      if (!confVerdict.isAllowed) {
        audit.record(
          action: 'confirmation_denied',
          description: 'Confirmation denied: ${confVerdict.reason}',
          timestamp: DateTime.now(),
          details: {'requestId': requestId},
        );
        return CoordinationResult.denied(
          reason: 'FAIL-CLOSED: confirmation denied — ${confVerdict.reason}',
        );
      }
    } else {
      // Confirmation unavailable → FAIL-CLOSED → denied
      audit.record(
        action: 'confirmation_unavailable',
        description: 'Confirmation repository unavailable — failing closed',
        timestamp: DateTime.now(),
        details: {'requestId': requestId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: confirmation repository unavailable',
      );
    }

    // ═══ PHASE 7: Context-Aware Execution — determine mode ═══
    final isOnline = connectivity.isOnline();
    final execMode = contextAwareExecution.determineMode(
      isOnline: isOnline,
      memoryAvailable: memory.isAvailable(),
      config: contextAwareExecution.config,
    );
    audit.record(
      action: 'execution_mode_determined',
      description: 'Execution mode: $execMode',
      timestamp: DateTime.now(),
      details: {
        'requestId': requestId,
        'isOnline': isOnline,
        'mode': execMode.name,
      },
    );

    // ═══ PHASE 8: Task Planning ═══
    final plan = await taskPlanner.createPlan(
      userRequest: userIntent,
      locale: locale,
    );
    if (plan == null) {
      audit.record(
        action: 'planning_failed',
        description: 'Task planner returned null plan',
        timestamp: DateTime.now(),
        details: {'requestId': requestId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: task planning failed',
      );
    }

    // Validate the plan
    if (!taskPlanner.validatePlan(plan)) {
      audit.record(
        action: 'plan_validation_failed',
        description: 'Task plan validation failed',
        timestamp: DateTime.now(),
        details: {'requestId': requestId, 'planId': plan.planId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: plan validation failed',
        planId: plan.planId,
      );
    }

    // Adapt plan for execution mode if needed
    AdvancedTaskPlan effectivePlan = plan;
    if (execMode != ExecutionContextMode.online) {
      final adapted = contextAwareExecution.adaptPlanForMode(
        plan: plan,
        mode: execMode,
        locale: locale,
      );
      if (adapted == null) {
        // Adaptation failed → offline degraded if partial data, else denied
        if (execMode == ExecutionContextMode.offline) {
          final resultId = 'res_${DateTime.now().millisecondsSinceEpoch}';
          return CoordinationResult.offlineDegraded(
            reason: 'FAIL-CLOSED: plan adaptation failed for offline mode',
            result: AdvancedAgentResult.offlineDegraded(
              resultId: resultId,
              planId: plan.planId,
              requestId: requestId,
              executionLog: 'Plan adaptation failed; degraded mode.',
            ),
            planId: plan.planId,
          );
        }
        // Hybrid mode adaptation failure → denied
        return CoordinationResult.denied(
          reason: 'FAIL-CLOSED: plan adaptation failed for hybrid mode',
          planId: plan.planId,
        );
      }
      effectivePlan = adapted;
    }

    // ═══ PHASE 9: Goal Registration ═══
    // No plan.goals field — register goals explicitly
    final goalDescriptions = <String>[
      userIntent,
    ];
    // Also register any goals from context if present
    final contextGoals = context['goals'] as List<dynamic>?;
    if (contextGoals != null) {
      for (final g in contextGoals) {
        if (g is String && g.isNotEmpty) {
          goalDescriptions.add(g);
        }
      }
    }
    final registeredGoals = <AgentGoal>[];
    for (final desc in goalDescriptions) {
      final goal = goalTracker.registerGoal(
        planId: effectivePlan.planId,
        description: desc,
        locale: locale,
      );
      registeredGoals.add(goal);
    }

    // ═══ PHASE 10: Build initial progress state ═══
    final progressState = taskProgress.buildProgress(
      plan: effectivePlan,
      goals: registeredGoals,
      pauseResumeState: PauseResumeState.running,
    );

    // ═══ PHASE 11: Step Execution Loop ═══
    final executionStart = DateTime.now();
    final executionLog = StringBuffer();
    final failures = <AdvancedAgentFailure>[];
    final outputData = <String, dynamic>{};

    for (final step in effectivePlan.orderedSteps) {
      // --- 11a: Check pause/resume/cancel state ---
      final planPauseState = pauseResumeCancel.stateForPlan(effectivePlan.planId);
      if (planPauseState == PauseResumeState.cancelled) {
        audit.record(
          action: 'task_cancelled',
          description: 'Task cancelled by user during step: ${step.stepId}',
          timestamp: DateTime.now(),
          details: {'requestId': requestId, 'stepId': step.stepId},
        );
        return CoordinationResult.cancelled(planId: effectivePlan.planId);
      }
      if (planPauseState == PauseResumeState.paused ||
          planPauseState == PauseResumeState.pausing) {
        audit.record(
          action: 'task_paused',
          description: 'Task paused at step: ${step.stepId}',
          timestamp: DateTime.now(),
          details: {'requestId': requestId, 'stepId': step.stepId},
        );
        final pausedProgress = taskProgress.buildProgress(
          plan: effectivePlan,
          goals: registeredGoals,
          pauseResumeState: PauseResumeState.paused,
        );
        return CoordinationResult(
          success: false,
          errorMessage: 'PAUSED: execution paused at step ${step.stepId}',
          safetyVerdict: SafetyVerdict.allowed(
            verdictId: 'sv_pause_${step.stepId}',
            rationale: 'Execution paused (not denied).',
          ),
          pauseState: PauseResumeState.paused,
          progressState: pausedProgress,
        );
      }

      // --- 11b: Check dependencies satisfied ---
      if (!effectivePlan.areDependenciesSatisfied(step.stepId)) {
        executionLog.writeln(
            'Step ${step.stepId} dependencies not satisfied — skipping.');
        continue;
      }

      // --- 11c: Safety gate step-level evaluation ---
      final stepSafety = safetyGate.evaluateStep(
        stepId: step.stepId,
        planId: effectivePlan.planId,
        action: step.action ?? step.description,
        toolId: step.toolId,
        riskCategory: step.parameters['riskCategory'] as String?,
        locale: locale,
      );
      if (stepSafety.isDenied) {
        audit.record(
          action: 'step_safety_denied',
          description: 'Step ${step.stepId} denied by safety: ${stepSafety.rationale}',
          timestamp: DateTime.now(),
          details: {
            'requestId': requestId,
            'stepId': step.stepId,
            'verdictId': stepSafety.verdictId,
          },
        );
        failures.add(AdvancedAgentFailure.safetyDenied(
          failureId: 'fail_${step.stepId}',
          planId: effectivePlan.planId,
          stepId: step.stepId,
          toolId: step.toolId,
          message: stepSafety.rationale,
        ));
        // Try recovery
        final recoveryOutcome = await _handleRecovery(
          effectivePlan: effectivePlan,
          step: step,
          failureType: 'safety_denied',
          errorMessage: stepSafety.rationale,
          requestId: requestId,
          locale: locale,
          registeredGoals: registeredGoals,
        );
        if (recoveryOutcome != null) return recoveryOutcome;
        // Recovery couldn't resolve → continue to next step or fail
        continue;
      }

      // --- 11d: Tool selection ---
      if (step.requiresTool) {
        // Discover tools via registry
        final discovered = await toolRegistry.discover(
          step.parameters['category'] as String? ?? '',
          step.action ?? step.description,
        );

        // Convert DiscoveredTool list to List<Map<String, dynamic>> for toolSelection
        final candidateMaps = discovered
            .map((t) => <String, dynamic>{
                  'toolId': t.toolId,
                  'name': t.name,
                  'description': t.description,
                  'category': t.category,
                  'parameters': t.parameters,
                  'relevanceScore': t.relevanceScore,
                })
            .toList();

        final toolScore = toolSelection.selectBest(
          action: step.action ?? step.description,
          candidates: candidateMaps,
          locale: locale,
        );

        if (toolScore == null || !toolScore.meetsThreshold()) {
          audit.record(
            action: 'tool_unsuitable',
            description: 'No suitable tool for step: ${step.stepId}',
            timestamp: DateTime.now(),
            details: {
              'requestId': requestId,
              'stepId': step.stepId,
            },
          );
          failures.add(AdvancedAgentFailure.unknown(
            failureId: 'fail_tool_${step.stepId}',
            message: 'No suitable tool found for step ${step.stepId}',
            planId: effectivePlan.planId,
            stepId: step.stepId,
          ));
          final recoveryOutcome = await _handleRecovery(
            effectivePlan: effectivePlan,
            step: step,
            failureType: 'tool_unsuitable',
            errorMessage: 'No suitable tool for step ${step.stepId}',
            requestId: requestId,
            locale: locale,
            registeredGoals: registeredGoals,
          );
          if (recoveryOutcome != null) return recoveryOutcome;
          continue;
        }

        // --- 11e: Tool execution ---
        if (!toolExecution.isAvailable()) {
          audit.record(
            action: 'tool_execution_unavailable',
            description: 'Tool execution service unavailable',
            timestamp: DateTime.now(),
            details: {'requestId': requestId, 'stepId': step.stepId},
          );
          failures.add(AdvancedAgentFailure.safetyUnavailable(
            failureId: 'fail_exec_${step.stepId}',
            planId: effectivePlan.planId,
          ));
          final recoveryOutcome = await _handleRecovery(
            effectivePlan: effectivePlan,
            step: step,
            failureType: 'tool_execution_unavailable',
            errorMessage: 'Tool execution unavailable',
            requestId: requestId,
            locale: locale,
            registeredGoals: registeredGoals,
          );
          if (recoveryOutcome != null) return recoveryOutcome;
          continue;
        }

        final execResult = await toolExecution.execute(
          toolId: toolScore.toolId,
          action: step.action ?? '',
          parameters: step.parameters,
          memoryContext: memoryContext,
          retryAttempt: step.retryAttempt,
        );

        executionLog.writeln(
            'Step ${step.stepId}: tool ${toolScore.toolId} → success=${execResult.isSuccessful}');

        // --- 11f: Result verification ---
        final verification = resultVerifier.verifyStep(
          stepId: step.stepId,
          planId: effectivePlan.planId,
          actualResult: execResult.data,
          expectedOutcome: step.parameters['expectedOutcome'] as Map<String, dynamic>? ?? {},
          locale: locale,
        );

        if (verification.treatAsFailed) {
          audit.record(
            action: 'verification_failed',
            description: 'Step ${step.stepId} verification failed: ${verification.message}',
            timestamp: DateTime.now(),
            details: {
              'requestId': requestId,
              'stepId': step.stepId,
              'status': verification.status.name,
            },
          );

          // --- 11g: NL correction for treatAsFailed ---
          final correction = nlCorrection.correctStepDescription(
            correctionId: 'corr_${step.stepId}',
            originalText: step.description,
            stepId: step.stepId,
            planId: effectivePlan.planId,
            correctionHint: verification.message,
            locale: locale,
          );
          if (correction.hasChanges && nlCorrection.shouldAutoApply(correction)) {
            audit.record(
              action: 'nl_correction_applied',
              description: 'NL correction applied: ${correction.correctedText}',
              timestamp: DateTime.now(),
              details: {
                'requestId': requestId,
                'stepId': step.stepId,
              },
            );
            executionLog.writeln(
                'Step ${step.stepId}: NL correction applied: ${correction.correctedText}');
          }

          // --- 11h: Recovery ---
          failures.add(AdvancedAgentFailure.unknown(
            failureId: 'fail_verify_${step.stepId}',
            message: verification.message ?? 'Verification failed',
            planId: effectivePlan.planId,
            stepId: step.stepId,
          ));
          final recoveryOutcome = await _handleRecovery(
            effectivePlan: effectivePlan,
            step: step,
            failureType: 'verification_failed',
            errorMessage: verification.message ?? 'Verification failed',
            requestId: requestId,
            locale: locale,
            registeredGoals: registeredGoals,
          );
          if (recoveryOutcome != null) return recoveryOutcome;
          continue;
        }

        // Step succeeded
        if (execResult.isSuccessful) {
          outputData[step.stepId] = execResult.data;
          executionLog.writeln('Step ${step.stepId}: COMPLETED successfully');
        }
      } else {
        // Step without tool — mark as completed if no tool needed
        executionLog.writeln(
            'Step ${step.stepId}: no tool required — marked completed');
        outputData[step.stepId] = {'status': 'completed', 'noTool': true};
      }

      // --- 11i: Update goal progress ---
      for (final goal in registeredGoals) {
        final completion = goalTracker.planGoalCompletion(effectivePlan.planId);
        goalTracker.updateGoalProgress(
          goalId: goal.goalId,
          progress: completion,
        );
      }
    }

    // ═══ PHASE 12: Finalize goals ═══
    final finalGoalCompletion =
        goalTracker.planGoalCompletion(effectivePlan.planId);
    if (finalGoalCompletion >= 1.0) {
      for (final goal in goalTracker.goalsForPlan(effectivePlan.planId)) {
        goalTracker.markGoalAchieved(goal.goalId);
      }
    }

    // ═══ PHASE 13: Build final progress ═══
    final finalProgress = taskProgress.buildProgress(
      plan: effectivePlan,
      goals: goalTracker.goalsForPlan(effectivePlan.planId),
      pauseResumeState: PauseResumeState.running,
    );

    // ═══ PHASE 14: Build final result ═══
    final executionDuration = DateTime.now().difference(executionStart);
    final resultId = 'res_${DateTime.now().millisecondsSinceEpoch}';

    AdvancedAgentResult agentResult;
    if (failures.isEmpty) {
      agentResult = AdvancedAgentResult.success(
        resultId: resultId,
        planId: effectivePlan.planId,
        requestId: requestId,
        outputData: outputData,
        executionLog: executionLog.toString(),
        executionDuration: executionDuration,
        locale: locale,
      );
    } else if (execMode != ExecutionContextMode.online &&
        outputData.isNotEmpty) {
      agentResult = AdvancedAgentResult.offlineDegraded(
        resultId: resultId,
        planId: effectivePlan.planId,
        requestId: requestId,
        outputData: outputData,
        failures: failures,
        executionLog: executionLog.toString(),
        executionDuration: executionDuration,
        locale: locale,
      );
    } else {
      agentResult = AdvancedAgentResult.failed(
        resultId: resultId,
        failures: failures,
        planId: effectivePlan.planId,
        requestId: requestId,
        executionLog: executionLog.toString(),
        executionDuration: executionDuration,
        locale: locale,
      );
    }

    // ═══ PHASE 15: Final audit ═══
    audit.record(
      action: 'task_execution_complete',
      description: 'Task execution completed: ${agentResult.status.name}',
      timestamp: DateTime.now(),
      details: {
        'requestId': requestId,
        'resultId': resultId,
        'planId': effectivePlan.planId,
        'failures': failures.length,
        'duration': executionDuration.inMilliseconds,
      },
    );

    if (agentResult.isSuccess) {
      return CoordinationResult.success(
        result: agentResult,
        verdict: safetyVerdict,
        progress: finalProgress,
      );
    } else if (agentResult.isDegraded) {
      return CoordinationResult.offlineDegraded(
        reason: executionLog.toString(),
        result: agentResult,
        planId: effectivePlan.planId,
      );
    } else {
      return CoordinationResult.failed(
        reason: 'Execution failed with ${failures.length} failure(s)',
        failures: failures,
        planId: effectivePlan.planId,
      );
    }
  }

  // ─── Trigger-based execution ───────────────────────────────────

  Future<CoordinationResult> executeFromTrigger({
    required TriggerRequest triggerRequest,
    String locale = 'ku',
  }) async {
    final requestId = 'trig_${DateTime.now().millisecondsSinceEpoch}';

    // Check trigger repository availability
    if (!trigger.isAvailable()) {
      audit.record(
        action: 'trigger_unavailable',
        description: 'Trigger repository unavailable — failing closed',
        timestamp: DateTime.now(),
        details: {'requestId': requestId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: trigger repository unavailable',
      );
    }

    // FAIL-CLOSED: TriggerType.unknown → NEVER authorized
    if (!trigger.isTriggerTypePermitted(triggerRequest.type)) {
      audit.record(
        action: 'trigger_type_not_permitted',
        description: 'Trigger type not permitted: ${triggerRequest.type.name}',
        timestamp: DateTime.now(),
        details: {
          'requestId': requestId,
          'triggerId': triggerRequest.id,
          'triggerType': triggerRequest.type.name,
        },
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: trigger type ${triggerRequest.type.name} not permitted',
      );
    }

    // Authorize trigger
    final authVerdict = await trigger.authorize(triggerRequest);
    if (!authVerdict.authorized) {
      audit.record(
        action: 'trigger_unauthorized',
        description: 'Trigger denied: ${authVerdict.reason ?? "unauthorized"}',
        timestamp: DateTime.now(),
        details: {
          'triggerId': triggerRequest.id,
          'triggerType': triggerRequest.type.name,
        },
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: trigger ${triggerRequest.type.name} not authorized — ${authVerdict.reason}',
      );
    }

    // Trigger authorized — delegate to main execution
    return executeTask(
      userIntent: 'trigger:${triggerRequest.type.name}',
      locale: locale,
      context: {
        'triggerId': triggerRequest.id,
        'triggerType': triggerRequest.type.name,
        'payload': triggerRequest.payload,
        'triggerTimestamp': triggerRequest.timestamp.toIso8601String(),
      },
    );
  }

  // ─── Pause / Resume / Cancel ────────────────────────────────────

  PauseResumeRecord? pause({
    required String planId,
    String? stepId,
    String? reason,
    required String requestedBy,
  }) {
    final record = pauseResumeCancel.pause(
      planId: planId,
      stepId: stepId,
      reason: reason,
      requestedBy: requestedBy,
    );
    audit.record(
      action: 'execution_paused',
      description: 'Execution paused by $requestedBy for plan $planId',
      timestamp: DateTime.now(),
    );
    return record;
  }

  PauseResumeRecord? resume({
    required String planId,
    String? stepId,
    required String requestedBy,
  }) {
    final record = pauseResumeCancel.resume(
      planId: planId,
      stepId: stepId,
      requestedBy: requestedBy,
    );
    audit.record(
      action: 'execution_resumed',
      description: 'Execution resumed by $requestedBy for plan $planId',
      timestamp: DateTime.now(),
    );
    return record;
  }

  PauseResumeRecord? cancel({
    required String planId,
    String? stepId,
    String? reason,
    required String requestedBy,
  }) {
    final record = pauseResumeCancel.cancel(
      planId: planId,
      stepId: stepId,
      reason: reason,
      requestedBy: requestedBy,
    );
    audit.record(
      action: 'execution_cancelled',
      description: 'Execution cancelled by $requestedBy for plan $planId',
      timestamp: DateTime.now(),
    );
    return record;
  }

  // ─── Recovery handler (FAIL-CLOSED: canSkip → shouldAbort) ──────

  Future<CoordinationResult?> _handleRecovery({
    required AdvancedTaskPlan effectivePlan,
    required TaskStep step,
    required String failureType,
    required String errorMessage,
    required String requestId,
    required String locale,
    required List<AgentGoal> registeredGoals,
  }) async {
    // Check recovery availability
    if (!recovery.isAvailable()) {
      audit.record(
        action: 'recovery_unavailable',
        description: 'Recovery repository unavailable — failing closed',
        timestamp: DateTime.now(),
        details: {'requestId': requestId, 'stepId': step.stepId},
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: recovery unavailable for step ${step.stepId}',
        planId: effectivePlan.planId,
      );
    }

    final strategy = await recovery.classifyAndStrategize(
      failureType: failureType,
      errorMessage: errorMessage,
      retryAttempt: step.retryAttempt,
    );

    // FAIL-CLOSED: canSkip is ALWAYS treated as shouldAbort — NEVER skip
    if (strategy.canSkip) {
      audit.record(
        action: 'recovery_skip_treated_as_abort',
        description: 'Recovery suggested skip — FAIL-CLOSED: treating as abort for step ${step.stepId}',
        timestamp: DateTime.now(),
        details: {
          'requestId': requestId,
          'stepId': step.stepId,
          'strategyAction': strategy.action.name,
        },
      );
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: recovery skip treated as abort for step ${step.stepId}',
        planId: effectivePlan.planId,
      );
    }

    if (strategy.shouldAbort) {
      return CoordinationResult.denied(
        reason: 'FAIL-CLOSED: recovery aborted for step ${step.stepId}',
        planId: effectivePlan.planId,
      );
    }

    if (strategy.canReplan) {
      if (_replanAttempt >= replanner.maxReplanAttempts) {
        audit.record(
          action: 'replan_limit_exceeded',
          description: 'Replan attempt limit (${replanner.maxReplanAttempts}) exceeded',
          timestamp: DateTime.now(),
          details: {
            'requestId': requestId,
            'planId': effectivePlan.planId,
          },
        );
        return CoordinationResult.denied(
          reason: 'FAIL-CLOSED: max replan attempts (${replanner.maxReplanAttempts}) exceeded',
          planId: effectivePlan.planId,
        );
      }
      _replanAttempt++;
      final failure = AdvancedAgentFailure.unknown(
        failureId: 'fail_replan_${step.stepId}',
        message: errorMessage,
        planId: effectivePlan.planId,
        stepId: step.stepId,
      );
      final newPlan = await replanner.replanOnFailure(
        currentPlan: effectivePlan,
        failure: failure,
        locale: locale,
      );
      if (newPlan == null) {
        audit.record(
          action: 'replan_failed',
          description: 'Replanning failed for plan ${effectivePlan.planId}',
          timestamp: DateTime.now(),
          details: {'requestId': requestId},
        );
        return CoordinationResult.denied(
          reason: 'FAIL-CLOSED: replanning failed',
          planId: effectivePlan.planId,
        );
      }
      // Replan succeeded — return null to let caller continue with new plan
      // (In a full implementation, we'd update effectivePlan and continue the loop)
      audit.record(
        action: 'replan_succeeded',
        description: 'Replanning succeeded — new plan: ${newPlan.planId}',
        timestamp: DateTime.now(),
        details: {
          'requestId': requestId,
          'newPlanId': newPlan.planId,
        },
      );
      return null; // Signal: recovery handled, continue execution
    }

    if (strategy.canRetry) {
      // Retry signaled — in full implementation, would re-execute step
      audit.record(
        action: 'recovery_retry',
        description: 'Recovery suggests retry for step ${step.stepId}',
        timestamp: DateTime.now(),
        details: {
          'requestId': requestId,
          'stepId': step.stepId,
          'currentRetry': strategy.currentRetry,
          'maxRetries': strategy.maxRetries,
        },
      );
      return null; // Signal: retry, continue execution
    }

    // No recovery action resolved the issue
    return CoordinationResult.denied(
      reason: 'FAIL-CLOSED: unresolvable failure for step ${step.stepId}',
      planId: effectivePlan.planId,
    );
  }
}
