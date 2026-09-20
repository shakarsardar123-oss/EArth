/// Step 23 — Agent Orchestrator
///
/// The CENTRAL coordination layer that connects Steps 16–22 into one coherent
/// production-level orchestration pipeline.
///
/// It ONLY coordinates — it does NOT duplicate functionality of subsystems.
///
/// Lifecycle:
///   USER → UNDERSTAND → MEMORY → PLAN → TOOL DISCOVERY →
///   SECURITY → PERMISSION → CONFIRMATION → EXECUTION →
///   VERIFICATION → RECOVERY → RESPONSE
///
/// FAIL-CLOSED invariants:
///   UNKNOWN = DENY
///   ERROR = DENY
///   UNAVAILABLE = DENY
///
/// Never bypass Step 16 permissions, Step 19 security, Step 20 allowlist,
/// or Step 22 execution gates.
/// Never directly execute an arbitrary tool.
/// Agent-generated actions are treated exactly like user-originated actions.

import '../../domain/orchestration_domain.dart';
import '../localization_service.dart';
import '../../../../core/errors/result.dart';

class AgentOrchestrator {
  final AgentEngineRepository _agentEngine;
  final MemoryRepository _memory;
  final ToolRegistryRepository _toolRegistry;
  final SecurityRepository _security;
  final PermissionRepository _permission;
  final ConfirmationRepository _confirmation;
  final ToolExecutionRepository _execution;
  final RecoveryRepository _recovery;
  final ConnectivityRepository _connectivity;
  final AuditRepository _audit;
  final AppLocalizationService _localization;

  AgentOrchestrator({
    required AgentEngineRepository agentEngine,
    required MemoryRepository memory,
    required ToolRegistryRepository toolRegistry,
    required SecurityRepository security,
    required PermissionRepository permission,
    required ConfirmationRepository confirmation,
    required ToolExecutionRepository execution,
    required RecoveryRepository recovery,
    required ConnectivityRepository connectivity,
    required AuditRepository audit,
    required AppLocalizationService localization,
  })  : _agentEngine = agentEngine,
        _memory = memory,
        _toolRegistry = toolRegistry,
        _security = security,
        _permission = permission,
        _confirmation = confirmation,
        _execution = execution,
        _recovery = recovery,
        _connectivity = connectivity,
        _audit = audit,
        _localization = localization;

  /// Main entry point — process a user request through the full pipeline.
  ///
  /// Returns an [OrchestrationResult] — never throws unhandled exceptions.
  /// All error paths produce a FAIL-CLOSED result.
  Future<OrchestrationResult> process(UnifiedRequestContext context) async {
    try {
      return await _runPipeline(context);
    } catch (e) {
      // FAIL-CLOSED: any unhandled exception → denied/failed
      await _audit.record(
        action: 'orchestration_error',
        description: 'Unhandled exception: $e',
        timestamp: DateTime.now(),
        details: {'requestId': context.requestId},
      );
      return OrchestrationResult.denied(
        requestId: context.requestId,
        errorCode: 'ORCHESTRATION_ERROR',
        errorMessage: e.toString(),
        localizedResponse: _localization.translate('error.orchestration_failed', context.locale),
      );
    }
  }

  /// Cancel an active request.
  /// Propagates cancellation through execution → recovery → voice/UI.
  Future<OrchestrationResult> cancel(UnifiedRequestContext context) async {
    try {
      await _execution.cancel();
    } catch (_) {
      // Cancellation must still succeed even if execution cancel fails
    }
    await _audit.record(
      action: 'cancelled',
      description: 'User cancelled request',
      timestamp: DateTime.now(),
      details: {'requestId': context.requestId},
    );
    return OrchestrationResult.cancelled(
      requestId: context.requestId,
      localizedResponse: _localization.translate('status.cancelled', context.locale),
    );
  }

  /// The full pipeline — each phase is a separate method for testability.
  Future<OrchestrationResult> _runPipeline(UnifiedRequestContext context) async {
    // ── 1. UNDERSTAND ──
    context = await _understand(context);
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 2. MEMORY LOOKUP ──
    if (context.state.phase == OrchestrationPhase.planning ||
        context.state.phase == OrchestrationPhase.memoryLookup) {
      context = await _memoryLookup(context);
    }
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 3. PLAN ──
    context = await _plan(context);
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 4. TOOL DISCOVERY ──
    if (context.state.phase == OrchestrationPhase.toolDiscovery) {
      context = await _toolDiscovery(context);
    }
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 5. SECURITY CHECK ──
    if (context.hasSelectedTool) {
      context = await _securityCheck(context);
    }
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 6. PERMISSION CHECK ──
    if (context.hasSelectedTool && context.securityCleared) {
      context = await _permissionCheck(context);
    }
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 7. CONFIRMATION ──
    if (context.hasSelectedTool && context.permissionGranted) {
      context = await _confirmationCheck(context);
    }
    if (context.state.phase == OrchestrationPhase.failed ||
        context.state.phase == OrchestrationPhase.cancelled) {
      return _toResult(context);
    }

    // ── 8. EXECUTE ──
    if (context.hasSelectedTool && context.mayExecute) {
      context = await _execute(context);
    }
    if (context.state.phase == OrchestrationPhase.cancelled) {
      return _toResult(context);
    }
    if (context.state.phase == OrchestrationPhase.recovering) {
      context = await _recover(context);
    }
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 9. VERIFY ──
    if (context.state.phase == OrchestrationPhase.verifying) {
      context = await _verify(context);
    }
    if (context.state.phase == OrchestrationPhase.recovering) {
      context = await _recover(context);
    }
    if (context.state.phase == OrchestrationPhase.failed) {
      return _toResult(context);
    }

    // ── 10. RESPOND ──
    context = await _respond(context);
    return _toResult(context);
  }

  // ────────────────────── PHASE IMPLEMENTATIONS ──────────────────────

  /// Phase: UNDERSTAND — delegate to AgentEngine.
  Future<UnifiedRequestContext> _understand(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.understanding));
    ctx = ctx.copyWith(state: state);

    await _audit.record(
      action: 'understanding',
      description: 'Understanding user request',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'userRequest': ctx.userRequest},
    );

    final intent = await _agentEngine.understand(ctx.userRequest, ctx.locale);
    if (intent == null) {
      // FAIL-CLOSED: understanding failure
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Understanding failed'),
      );
    }

    // Store full intent in context for downstream phases
    ctx = ctx.copyWith(
      intent: intent,
      isScreenAction: intent.isScreenAction,
    );

    // Transition to planning
    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.understanding, OrchestrationPhase.planning));
    return ctx.copyWith(state: newState);
  }

  /// Phase: MEMORY LOOKUP — delegate to Step 17 Semantic Memory.
  /// Memory failure degrades safely — does NOT block orchestration.
  Future<UnifiedRequestContext> _memoryLookup(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.memoryLookup));
    ctx = ctx.copyWith(state: state);

    await _audit.record(
      action: 'memory_lookup',
      description: 'Looking up memory context',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId},
    );

    final available = await _memory.isAvailable();
    if (!available) {
      // Safe degradation — memory unavailable, continue without it
      await _audit.record(
        action: 'memory_unavailable',
        description: 'Memory unavailable, continuing without context',
        timestamp: DateTime.now(),
      );
      // Return to planning without memory
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.memoryLookup, OrchestrationPhase.planning));
      return ctx.copyWith(state: newState);
    }

    final memoryCtx = await _memory.lookup(ctx.userRequest, ctx.locale);
    if (memoryCtx == null) {
      // Safe degradation — memory returned nothing
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.memoryLookup, OrchestrationPhase.planning));
      return ctx.copyWith(state: newState, memoryContext: memoryCtx);
    }

    // Enrich context with memory
    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.memoryLookup, OrchestrationPhase.planning));
    return ctx.copyWith(state: newState, memoryContext: memoryCtx);
  }

  /// Phase: PLAN — delegate to AgentEngine.
  /// Reuses ctx.intent from understanding phase (never re-understands).
  Future<UnifiedRequestContext> _plan(UnifiedRequestContext ctx) async {
    final intent = ctx.intent!;
    final plan = await _agentEngine.plan(intent, ctx.memoryContext);
    if (plan == null) {
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Planning failed'),
      );
    }

    await _audit.record(
      action: 'planned',
      description: 'Plan created: needsTool=${plan.needsTool}, needsScreen=${plan.needsScreenAction}',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'planId': plan.planId},
    );

    if (plan.isDirectResponse) {
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.planning, OrchestrationPhase.responding));
      return ctx.copyWith(
        state: newState,
        memoryContext: plan.suggestedResponse, // use as response text
      );
    }

    // Determine next phase based on plan
    OrchestrationPhase nextPhase;
    if (plan.needsTool || plan.needsScreenAction) {
      nextPhase = OrchestrationPhase.toolDiscovery;
    } else {
      nextPhase = OrchestrationPhase.responding;
    }

    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.planning, nextPhase));
    return ctx.copyWith(
      state: newState,
      isScreenAction: plan.needsScreenAction,
    );
  }

  /// Phase: TOOL DISCOVERY — delegate to Step 20 Tool Registry.
  /// Reuses ctx.intent from understanding phase (never re-understands).
  Future<UnifiedRequestContext> _toolDiscovery(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.toolDiscovery));
    ctx = ctx.copyWith(state: state);

    await _audit.record(
      action: 'tool_discovery',
      description: 'Discovering tools for request',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'isScreenAction': ctx.isScreenAction},
    );

    // Check offline status for cloud-only tools
    final isOnline = await _connectivity.isOnline();
    ctx = ctx.copyWith(isOffline: !isOnline);

    if (ctx.isScreenAction) {
      // Screen actions use the screen repository, but still go through security
      // Screen tools are typically local
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.toolDiscovery, OrchestrationPhase.securityChecking));
      return ctx.copyWith(
        state: newState,
        selectedToolId: 'screen_control',
        toolRiskLevel: 'medium',
      );
    }

    // Reuse intent from context (never re-understand)
    final category = ctx.intent != null ? _inferCategory(ctx.intent!) : null;

    final discovered = await _toolRegistry.discover(category, ctx.userRequest);
    if (discovered.isEmpty) {
      // No tool found — direct response
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.toolDiscovery, OrchestrationPhase.responding));
      return ctx.copyWith(state: newState);
    }

    // Filter for offline compatibility
    final usableTools = ctx.isOffline
        ? discovered.where((t) => t.isLocal && !t.requiresCloud).toList()
        : discovered;

    if (usableTools.isEmpty && ctx.isOffline) {
      // Offline and no local tools available
      return ctx.copyWith(
        state: ctx.state.copyWith(
          phase: OrchestrationPhase.failed,
          errorMessage: 'No local tools available offline',
        ),
      );
    }

    final selected = await _toolRegistry.selectBest(usableTools, ctx.userRequest);
    if (selected == null) {
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.toolDiscovery, OrchestrationPhase.responding));
      return ctx.copyWith(state: newState);
    }

    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.toolDiscovery, OrchestrationPhase.securityChecking));
    return ctx.copyWith(
      state: newState,
      selectedToolId: selected.toolId,
      toolRiskLevel: selected.riskLevel,
    );
  }

  /// Phase: SECURITY CHECK — delegate to Step 19.
  /// NEVER assume an action is safe because it came from AgentEngine.
  Future<UnifiedRequestContext> _securityCheck(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.securityChecking));
    ctx = ctx.copyWith(state: state);

    final toolId = ctx.selectedToolId ?? 'unknown';
    final riskLevel = ctx.toolRiskLevel ?? 'high'; // FAIL-CLOSED: unknown risk = high

    await _audit.record(
      action: 'security_check',
      description: 'Checking security for tool: $toolId',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'toolId': toolId, 'riskLevel': riskLevel},
    );

    final securityAvailable = await _security.isAvailable();
    if (!securityAvailable) {
      // FAIL-CLOSED: security unavailable = denied
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Security subsystem unavailable'),
      );
    }

    final verdict = await _security.check('execute:$toolId', toolId, riskLevel);
    if (!verdict.allowed) {
      await _audit.record(
        action: 'security_denied',
        description: 'Security denied: ${verdict.reason}',
        timestamp: DateTime.now(),
        details: {'requestId': ctx.requestId, 'toolId': toolId},
      );
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Security denied: ${verdict.reason}'),
        securityCleared: false,
      );
    }

    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.securityChecking, OrchestrationPhase.permissionChecking));
    return ctx.copyWith(state: newState, securityCleared: true);
  }

  /// Phase: PERMISSION CHECK — delegate to Step 16.
  /// Never fake permission success.
  Future<UnifiedRequestContext> _permissionCheck(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.permissionChecking));
    ctx = ctx.copyWith(state: state);

    final toolId = ctx.selectedToolId ?? 'unknown';

    await _audit.record(
      action: 'permission_check',
      description: 'Checking permissions for tool: $toolId',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'toolId': toolId},
    );

    final permAvailable = await _permission.isAvailable();
    if (!permAvailable) {
      // FAIL-CLOSED: permission subsystem unavailable = denied
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Permission subsystem unavailable'),
      );
    }

    final verdict = await _permission.check('execute:$toolId', toolId);
    if (!verdict.granted) {
      // Try requesting the permission
      final requestVerdict = await _permission.request('execute:$toolId', toolId);
      if (!requestVerdict.granted) {
        await _audit.record(
          action: 'permission_denied',
          description: 'Permission denied: ${requestVerdict.reason}',
          timestamp: DateTime.now(),
          details: {'requestId': ctx.requestId, 'toolId': toolId, 'shouldOpenSettings': requestVerdict.shouldOpenSettings},
        );
        return ctx.copyWith(
          state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Permission denied: ${requestVerdict.reason}'),
          permissionGranted: false,
        );
      }
    }

    // Determine if confirmation is needed based on risk level
    final riskLevel = ctx.toolRiskLevel ?? 'high';
    OrchestrationPhase nextPhase;
    if (riskLevel == 'low') {
      // Low risk may auto-approve, skip confirmation
      nextPhase = OrchestrationPhase.executing;
    } else {
      nextPhase = OrchestrationPhase.awaitingConfirmation;
    }

    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.permissionChecking, nextPhase));
    return ctx.copyWith(state: newState, permissionGranted: true, confirmationObtained: riskLevel == 'low');
  }

  /// Phase: CONFIRMATION CHECK — delegate to Step 20.
  /// Never silently approve a denied confirmation.
  Future<UnifiedRequestContext> _confirmationCheck(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.awaitingConfirmation));
    ctx = ctx.copyWith(state: state);

    final toolId = ctx.selectedToolId ?? 'unknown';
    final riskLevel = ctx.toolRiskLevel ?? 'high';

    await _audit.record(
      action: 'confirmation_check',
      description: 'Checking confirmation for tool: $toolId, risk: $riskLevel',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'toolId': toolId, 'riskLevel': riskLevel},
    );

    final confirmAvailable = await _confirmation.isAvailable();
    if (!confirmAvailable) {
      // FAIL-CLOSED: confirmation unavailable = denied
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Confirmation subsystem unavailable'),
      );
    }

    final verdict = await _confirmation.checkAndObtain(
      toolId: toolId,
      riskLevel: riskLevel,
      userRequest: ctx.userRequest,
    );

    if (!verdict.obtained) {
      await _audit.record(
        action: 'confirmation_denied',
        description: 'Confirmation denied: ${verdict.reason}',
        timestamp: DateTime.now(),
        details: {'requestId': ctx.requestId, 'toolId': toolId, 'mode': verdict.mode.name},
      );

      if (verdict.mode == ConfirmationMode.denyAll) {
        // denyAll → never execute
        return ctx.copyWith(
          state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'denyAll policy: execution denied'),
          confirmationObtained: false,
        );
      }

      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Confirmation denied: ${verdict.reason}'),
        confirmationObtained: false,
      );
    }

    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.awaitingConfirmation, OrchestrationPhase.executing));
    return ctx.copyWith(state: newState, confirmationObtained: true);
  }

  /// Phase: EXECUTE — delegate to Step 22 Tool Execution Engine.
  /// The orchestrator NEVER directly executes an arbitrary tool.
  Future<UnifiedRequestContext> _execute(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.executing));
    ctx = ctx.copyWith(state: state);

    final toolId = ctx.selectedToolId ?? 'unknown';

    await _audit.record(
      action: 'executing',
      description: 'Executing tool: $toolId',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'toolId': toolId},
    );

    final execAvailable = await _execution.isAvailable();
    if (!execAvailable) {
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Execution engine unavailable'),
      );
    }

    if (ctx.isCancelled) {
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.cancelled),
      );
    }

    final result = await _execution.execute(
      toolId: toolId,
      action: ctx.userRequest,
      parameters: {},
      memoryContext: ctx.memoryContext,
      retryAttempt: ctx.state.retryAttempt,
    );

    if (result.wasCancelled) {
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.cancelled),
        isCancelled: true,
      );
    }

    if (result.wasDenied) {
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Execution denied: ${result.errorMessage}'),
      );
    }

    if (!result.succeeded) {
      // Execution failed → attempt recovery
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
          OrchestrationPhase.executing, OrchestrationPhase.recovering)),
        executionSucceeded: false,
      );
    }

    // Execution succeeded → verify
    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.executing, OrchestrationPhase.verifying));
    return ctx.copyWith(state: newState, executionSucceeded: true);
  }

  /// Phase: VERIFY — basic post-execution sanity check.
  Future<UnifiedRequestContext> _verify(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.verifying));
    ctx = ctx.copyWith(state: state);

    await _audit.record(
      action: 'verifying',
      description: 'Verifying execution result',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId},
    );

    if (ctx.executionSucceeded) {
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.verifying, OrchestrationPhase.completed));
      return ctx.copyWith(state: newState);
    } else {
      // Verification failed → recovery
      final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
        OrchestrationPhase.verifying, OrchestrationPhase.recovering));
      return ctx.copyWith(state: newState);
    }
  }

  /// Phase: RECOVERY — delegate to Step 18.
  /// Do not create a second recovery engine.
  Future<UnifiedRequestContext> _recover(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.recovering));
    ctx = ctx.copyWith(state: state);

    await _audit.record(
      action: 'recovering',
      description: 'Attempting recovery, attempt ${ctx.state.retryAttempt}',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId, 'retryAttempt': ctx.state.retryAttempt},
    );

    final recoveryAvailable = await _recovery.isAvailable();
    if (!recoveryAvailable) {
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Recovery subsystem unavailable'),
        recoveryAttempted: true,
        recoverySucceeded: false,
      );
    }

    final strategy = await _recovery.classifyAndStrategize(
      failureType: 'execution_failure',
      errorMessage: ctx.state.errorMessage ?? 'unknown',
      retryAttempt: ctx.state.retryAttempt,
    );

    if (strategy.action == RecoveryAction.abort || !strategy.canRetry) {
      return ctx.copyWith(
        state: ctx.state.copyWith(phase: OrchestrationPhase.failed, errorMessage: 'Recovery exhausted: abort'),
        recoveryAttempted: true,
        recoverySucceeded: false,
      );
    }

    final recovered = await _recovery.executeStrategy(strategy);
    if (!recovered) {
      return ctx.copyWith(
        state: ctx.state.copyWith(
          phase: OrchestrationPhase.failed,
          errorMessage: 'Recovery strategy failed',
          retryAttempt: ctx.state.retryAttempt + 1,
        ),
        recoveryAttempted: true,
        recoverySucceeded: false,
      );
    }

    // Recovery succeeded — retry execution or replan
    OrchestrationPhase nextPhase;
    if (strategy.action == RecoveryAction.replan ||
        strategy.action == RecoveryAction.reunderstand ||
        strategy.action == RecoveryAction.recapture) {
      nextPhase = OrchestrationPhase.planning;
    } else {
      nextPhase = OrchestrationPhase.executing;
    }

    final newState = ctx.state.copyWith(
      phase: OrchestrationTransition.safeTransition(OrchestrationPhase.recovering, nextPhase),
      retryAttempt: ctx.state.retryAttempt + 1,
    );
    return ctx.copyWith(
      state: newState,
      recoveryAttempted: true,
      recoverySucceeded: true,
    );
  }

  /// Phase: RESPOND — produce the final user-facing response.
  Future<UnifiedRequestContext> _respond(UnifiedRequestContext ctx) async {
    final state = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      ctx.state.phase, OrchestrationPhase.responding));
    ctx = ctx.copyWith(state: state);

    await _audit.record(
      action: 'responding',
      description: 'Generating response',
      timestamp: DateTime.now(),
      details: {'requestId': ctx.requestId},
    );

    final newState = ctx.state.copyWith(phase: OrchestrationTransition.safeTransition(
      OrchestrationPhase.responding, OrchestrationPhase.completed));
    return ctx.copyWith(state: newState);
  }

  // ────────────────────── HELPERS ──────────────────────

  /// Convert final context to result.
  OrchestrationResult _toResult(UnifiedRequestContext ctx) {
    final phase = ctx.state.phase;
    final locale = ctx.locale;

    if (phase == OrchestrationPhase.completed) {
      return OrchestrationResult.success(
        requestId: ctx.requestId,
        responseText: ctx.memoryContext ?? 'Completed',
        localizedResponse: _localization.translate('status.completed', locale),
        selectedToolId: ctx.selectedToolId,
      );
    }

    if (phase == OrchestrationPhase.cancelled) {
      return OrchestrationResult.cancelled(
        requestId: ctx.requestId,
        localizedResponse: _localization.translate('status.cancelled', locale),
      );
    }

    // failed — determine if denied or just failed
    if (!ctx.securityCleared) {
      return OrchestrationResult.denied(
        requestId: ctx.requestId,
        errorCode: 'SECURITY_DENIED',
        errorMessage: ctx.state.errorMessage ?? 'Security check failed',
        localizedResponse: _localization.translate('error.security_denied', locale),
      );
    }

    if (!ctx.permissionGranted) {
      return OrchestrationResult.denied(
        requestId: ctx.requestId,
        errorCode: 'PERMISSION_DENIED',
        errorMessage: ctx.state.errorMessage ?? 'Permission denied',
        localizedResponse: _localization.translate('error.permission_denied', locale),
      );
    }

    if (!ctx.confirmationObtained) {
      return OrchestrationResult.denied(
        requestId: ctx.requestId,
        errorCode: 'CONFIRMATION_DENIED',
        errorMessage: ctx.state.errorMessage ?? 'Confirmation denied',
        localizedResponse: _localization.translate('error.confirmation_denied', locale),
      );
    }

    if (ctx.isOffline) {
      return OrchestrationResult.offlineDegraded(
        requestId: ctx.requestId,
        localizedResponse: _localization.translate('error.offline_degraded', locale),
      );
    }

    return OrchestrationResult.failed(
      requestId: ctx.requestId,
      errorCode: 'EXECUTION_FAILED',
      errorMessage: ctx.state.errorMessage ?? 'Execution failed',
      localizedResponse: _localization.translate('error.execution_failed', locale),
      totalRetryAttempts: ctx.state.retryAttempt,
    );
  }

  /// Infer tool category from intent for discovery.
  String? _inferCategory(AgentIntent intent) {
    if (intent.isScreenAction) return 'screen_control';
    if (intent.isToolAction) return 'general';
    return null;
  }
}
