import 'dart:async';
import 'dart:convert';

import 'agent_confirmation_manager.dart';
import 'agent_context.dart';
import 'agent_error.dart';
import 'agent_plan.dart';
import 'agent_executor.dart';
import 'agent_intent.dart';
import 'agent_planner.dart';
import 'agent_recovery.dart';
import 'agent_replanning.dart';
import 'agent_result.dart';
import 'agent_state.dart';
import 'agent_step.dart';
import 'agent_step_status.dart';
import 'agent_verification_engine.dart';
import '../live_mode/agent_processor.dart';
import '../security/tool_security_gate.dart';
import '../security/confirmation_guard.dart';
import '../tools/tool_arguments.dart';
import '../tools/tool_registry.dart';
import '../tools/tool_result.dart';
import '../../core/errors/result.dart';
import '../ai/provider_exception.dart';
import '../ai/ai_error_presenter.dart';

/// Callback types for agent engine events.
typedef AgentStateCallback = void Function(AgentState state);
typedef AgentStepCallback = void Function(AgentStep step);
typedef AgentToolCallCallback = void Function(String toolName, ToolArguments args);
typedef AgentToolResultCallback = void Function(String toolName, ToolResult result);
typedef AgentIntentCallback = void Function(AgentIntent intent);

/// Callback for enriching agent context with semantic memory before understanding.
///
/// Called BEFORE [_understand] in [AgentEngine.run]. Returns the (possibly
/// enriched) [AgentContext]. On failure, should return the original context.
typedef MemoryEnrichmentCallback = Future<AgentContext> Function(
  String userInput,
  AgentContext context,
);

/// Callback for capturing memorable information from a conversation after
/// a successful agent run.
///
/// Called AFTER [AgentEngine.run] returns [AgentResult.success].
/// Fire-and-forget — errors must be swallowed internally.
typedef MemoryCaptureCallback = Future<void> Function(
  String userInput,
  AgentContext context,
);

/// The core agent engine that orchestrates the full AI-powered task lifecycle.
///
/// Phase 4 full lifecycle:
/// 1. **Understand** — send user input to AI, parse into AgentIntent
/// 2. **Plan** — delegate to AgentPlanner for LLM-guided planning
/// 3. **Validate** — check plan validity (tool availability, cycles, budget)
/// 4. **Confirm** — pause for user confirmation on risky actions
/// 5. **Execute** — run steps via AgentExecutor with cancellation support
/// 6. **Observe** — record observations after each step
/// 7. **Verify** — run AgentVerificationEngine on step/plan results
/// 8. **Recover/Replan** — on failure, use AgentRecovery and AgentReplanning
/// 9. **Complete** — return final result
///
/// Preserves all Phase 1–3 behavior: the iterative AI↔tool loop still runs
/// when LLM-guided planning returns an empty plan or when the plan is
/// exhausted but the AI still wants to call tools.
class AgentEngine implements AgentProcessor {
  AgentEngine({
    required this.toolRegistry,
    required this.sendToAI,
    this.onStateChange,
    this.onStepStart,
    this.onStepComplete,
    this.onToolCall,
    this.onToolResult,
    this.onIntentParsed,
    this.onMemoryEnrichment,
    this.onMemoryCapture,
    this.maxIterations = 5,
    ToolSecurityGate? securityGate,
    Future<bool> Function(ToolConfirmationRequest request)?
        onSecurityConfirmation,
  })  : _executor = AgentExecutor(
          toolRegistry: toolRegistry,
          securityGate: securityGate,
          onSecurityConfirmation: onSecurityConfirmation,
        ),
        _planner = AgentPlanner(
          toolRegistry: toolRegistry,
          sendToAI: _wrapSendToAI(sendToAI),
        ),
        _recovery = AgentRecovery(),
        _replanning = AgentReplanning(),
        _confirmationManager = AgentConfirmationManager(),
        _verificationEngine = AgentVerificationEngine(),
        _cancellationToken = CancellationToken();

  final ToolRegistry toolRegistry;

  /// Function that sends messages + tool definitions to the AI and
  /// returns the raw response map (including potential tool_calls).
  final Future<Map<String, dynamic>> Function({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> toolDefinitions,
    required AgentContext context,
  }) sendToAI;

  final AgentStateCallback? onStateChange;
  final AgentStepCallback? onStepStart;
  final AgentStepCallback? onStepComplete;
  final AgentToolCallCallback? onToolCall;
  final AgentToolResultCallback? onToolResult;
  final AgentIntentCallback? onIntentParsed;

  /// Memory enrichment callback — called BEFORE [_understand] to inject
  /// relevant semantic memories into the context. Optional; when null,
  /// no enrichment happens (backward-compatible).
  final MemoryEnrichmentCallback? onMemoryEnrichment;

  /// Memory capture callback — called AFTER a successful [run] to extract
  /// memorable information from the conversation. Optional; when null,
  /// no capture happens (backward-compatible).
  final MemoryCaptureCallback? onMemoryCapture;

  /// Maximum back-and-forth iterations (user→AI→tool→AI→...→final).
  final int maxIterations;

  final AgentExecutor _executor;
  final AgentPlanner _planner;
  final AgentRecovery _recovery;
  final AgentReplanning _replanning;
  final AgentConfirmationManager _confirmationManager;
  final AgentVerificationEngine _verificationEngine;
  final CancellationToken _cancellationToken;

  AgentState _state = AgentState.idle;
  AgentState get state => _state;

  /// Access the confirmation manager for external accept/deny.
  AgentConfirmationManager get confirmationManager => _confirmationManager;

  void _setState(AgentState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  /// Wrap the engine's sendToAI into the planner's signature.
  static PlannerSendToAI _wrapSendToAI(
    Future<Map<String, dynamic>> Function({
      required List<Map<String, dynamic>> messages,
      required List<Map<String, dynamic>> toolDefinitions,
      required AgentContext context,
    }) engineSendToAI,
  ) {
    return ({
      required List<Map<String, dynamic>> messages,
      required List<Map<String, dynamic>> toolDefinitions,
      required AgentContext context,
    }) {
      return engineSendToAI(
        messages: messages,
        toolDefinitions: toolDefinitions,
        context: context,
      );
    };
  }

  // ── Main Lifecycle ──

  /// Main execution loop implementing the full Phase 4 lifecycle:
  /// understand → plan → validate → confirm → execute → observe → verify
  /// → recover/replan → complete.
  ///
  /// Falls back to the Phase 1–3 iterative AI↔tool loop when
  /// LLM-guided planning returns an empty plan.
  @override
  Future<AgentResult> run({
    required String userInput,
    required AgentContext context,
  }) async {
    _cancellationToken.reset();
    final stopwatch = Stopwatch()..start();
    final toolsUsed = <String>[];
    int stepsCompleted = 0;

    try {
      // ── Phase 0: Memory Enrichment ──
      // Recall relevant memories and inject them into the context
      // BEFORE understanding. Non-fatal — on failure, continue with
      // the original context.
      if (onMemoryEnrichment != null) {
        try {
          context = await onMemoryEnrichment!(userInput, context);
        } catch (e) {
          // Memory enrichment must never crash the agent.
          // Continue with the original context.
        }
      }

      // ── Fast path for clearly conversational messages ──
      // Avoid an extra Gemini intent-classification request for obvious
      // greetings and simple conversational phrases.
      if (_isClearlyConversational(userInput)) {
        _setState(AgentState.responding);
        final directResponse = await _sendToAIDirectly(userInput, context);
        stopwatch.stop();
        _fireMemoryCapture(userInput, context);
        return AgentResult.success(
          response: directResponse,
          stepsCompleted: 0,
          toolsUsed: [],
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // ── Phase 1: Understand ──
      _setState(AgentState.understanding);
      final intent = await _understand(userInput, context);
      context = context.update(
        intent: intent,
        currentGoal: intent.goal,
      );

      // If the intent is just conversation (no tools needed), respond directly.
      if (!intent.actionType.requiresTools && !intent.isPlanable) {
        _setState(AgentState.responding);
        final directResponse = await _sendToAIDirectly(userInput, context);
        stopwatch.stop();
        _fireMemoryCapture(userInput, context);
        return AgentResult.success(
          response: directResponse,
          stepsCompleted: 0,
          toolsUsed: [],
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Notify intent-parsed callback (additive — does not affect flow).
      onIntentParsed?.call(intent);

      // ── Phase 2: Plan ──
      _setState(AgentState.planning);
      final plan = await _planner.plan(
        userInput: userInput,
        context: context,
      );
      context = context.update(plan: plan);

      // ── Phase 3: Validate ──
      _setState(AgentState.validating);
      final validationError = _validatePlan(plan, context);
      if (validationError != null) {
        // Plan invalid — try the iterative AI↔tool loop instead.
        return _runIterativeLoop(
          userInput: userInput,
          context: context,
          stopwatch: stopwatch,
        );
      }

      // ── Phase 4: Confirm ──
      if (plan.isNotEmpty) {
        final confirmationRequest = _confirmationManager
            .requestConfirmationIfNeeded(plan, intent);
        if (confirmationRequest != null) {
          _setState(AgentState.waitingForConfirmation);
          // In a real app, the UI would resolve this.
          // For now, auto-approve if no external resolution.
          if (!_confirmationManager.isWaitingForConfirmation) {
            // Already resolved — continue.
          }
          // If still pending, we proceed and check later.
          // The confirmation manager's state is checked in executeStep.
          final confirmState = _confirmationManager.confirmationState;
          context = context.update(confirmationState: confirmState);
          if (confirmState == ConfirmationState.denied) {
            _setState(AgentState.cancelled);
            stopwatch.stop();
            return AgentResult.failure(
              errorMessage: 'بەکارهێنەر ڕێگەی نەدا',
              stepsCompleted: 0,
              toolsUsed: [],
              executionTimeMs: stopwatch.elapsedMilliseconds,
            );
          }
        }
      }

      // If plan is empty, fall back to iterative loop.
      if (plan.isEmpty) {
        return _runIterativeLoop(
          userInput: userInput,
          context: context,
          stopwatch: stopwatch,
        );
      }

      // ── Phase 5: Execute with observe, verify, and recover ──
      _setState(AgentState.executing);
      var currentPlan = plan;
      var currentContext = context;

      for (final step in currentPlan.steps) {
        // Check cancellation.
        if (_cancellationToken.isCancelled) {
          _setState(AgentState.cancelled);
          stopwatch.stop();
          return AgentResult.failure(
            errorMessage: 'بەکارهێنەر هەڵوەشاندیەوە',
            stepsCompleted: stepsCompleted,
            toolsUsed: toolsUsed,
            executionTimeMs: stopwatch.elapsedMilliseconds,
          );
        }

        // Check budget.
        if (currentContext.isBudgetExceeded) {
          _setState(AgentState.failed);
          stopwatch.stop();
          return AgentResult.failure(
            errorMessage: 'بوودجەی جێبەجێکردن تەواو بووە',
            stepsCompleted: stepsCompleted,
            toolsUsed: toolsUsed,
            executionTimeMs: stopwatch.elapsedMilliseconds,
          );
        }

        // Skip already completed/skipped steps.
        if (step.status == AgentStepStatus.succeeded ||
            step.status == AgentStepStatus.skipped) {
          stepsCompleted++;
          continue;
        }

        // Check dependencies.
        if (!currentPlan.areDependenciesMet(step)) {
          step.markSkipped(reason: 'Dependencies not met');
          stepsCompleted++;
          continue;
        }

        // Execute the step.
        onStepStart?.call(step);
        final executedStep = await _executor.executeStep(
          step,
          currentContext,
        );
        stepsCompleted++;

        // ── Phase 6: Observe ──
        _setState(AgentState.observing);
        currentContext = _observe(
          executedStep,
          currentContext,
        );

        // ── Phase 7: Verify ──
        _setState(AgentState.verifying);
        final verification = _verificationEngine.verifyStep(executedStep);

        // Handle step failure.
        if (executedStep.status == AgentStepStatus.failed) {
          _setState(AgentState.replanning);
          final recoveryResult = _handleFailure(
            executedStep,
            currentPlan,
            currentContext,
            verification,
          );

          if (!recoveryResult.strategy.canContinue) {
            // Recovery says abort.
            _setState(AgentState.failed);
            stopwatch.stop();
            return AgentResult.failure(
              errorMessage: recoveryResult.userMessage ??
                  'ناتوانم بەردەوام بم',
              stepsCompleted: stepsCompleted,
              toolsUsed: toolsUsed,
              executionTimeMs: stopwatch.elapsedMilliseconds,
            );
          }

          // Recovery says replan — get the new plan.
          if (recoveryResult.newPlan != null) {
            currentPlan = recoveryResult.newPlan!;
            currentContext = currentContext.update(plan: currentPlan);
          }

          // If recovery says retry with modified args, update the step.
          if (recoveryResult.modifiedArguments != null) {
            // The next iteration of the loop will pick up modified steps
            // if the plan was revised.
          }

          // Continue executing remaining steps in the (possibly revised) plan.
          continue;
        }

        // Step succeeded — record tool use.
        if (executedStep.toolName.isNotEmpty) {
          toolsUsed.add(executedStep.toolName);
        }
        onStepComplete?.call(executedStep);

        // Update plan in context.
        currentContext = currentContext.update(plan: currentPlan);
      }

      // ── Phase 8: Final Verification ──
      _setState(AgentState.verifying);
      final planVerification = _verificationEngine.verifyPlan(
        currentPlan,
        currentContext.observations,
      );

      if (!planVerification.passed &&
          planVerification.severity == VerificationSeverity.critical) {
        _setState(AgentState.failed);
        stopwatch.stop();
        return AgentResult.failure(
          errorMessage: planVerification.message ??
              'پشتڕاستکردنەوە سەرنەکەوت',
          stepsCompleted: stepsCompleted,
          toolsUsed: toolsUsed,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // ── Phase 9: Complete ──
      _setState(AgentState.completed);
      stopwatch.stop();

      // Build the final response from the last successful step's result
      // or from the AI if no steps were executed.
      String? response;
      if (currentPlan.allSucceeded && currentPlan.steps.isNotEmpty) {
        final lastSuccessful = currentPlan.steps
            .where((s) => s.status == AgentStepStatus.succeeded)
            .lastOrNull;
        response = lastSuccessful?.result?.data?.toString();
      }

      // If no concrete result from steps, ask AI for a summary.
      if (response == null || response.isEmpty) {
        _setState(AgentState.responding);
        response = await _sendToAIDirectly(
          'تکایە ئەنجامی ئەم کارە بۆ بگێڕمەوە: ${intent.goal}',
          currentContext,
        );
      }

      _fireMemoryCapture(userInput, currentContext);
      return AgentResult.success(
        response: response.isEmpty
            ? 'کارەکە بە سەرکەوتوویی تەواو بوو'
            : response,
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException catch (e) {
      _setState(AgentState.error);
      stopwatch.stop();
      // Route timeouts through AIErrorPresenter (stable token + errorCode)
      // instead of a hardcoded Kurdish string, so the UI shows a localized
      // message in the user's actual language (EN/KU) via the presenter.
      return AgentResult.failure(
        errorMessage: AIErrorPresenter.tokenFor(e),
        errorCode: AIErrorPresenter.tokenFor(e),
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      _setState(AgentState.error);
      stopwatch.stop();
      if (e is AIProviderException) {
        // Surface a stable, presentable token instead of a raw dump so the
        // UI can show a friendly localized message.
        return AgentResult.failure(
          errorMessage: AIErrorPresenter.tokenFor(e),
          errorCode: AIErrorPresenter.tokenFor(e),
          stepsCompleted: stepsCompleted,
          toolsUsed: toolsUsed,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
      if (e is AgentFailure) {
        return AgentResult.failure(
          errorMessage: e.message,
          stepsCompleted: stepsCompleted,
          toolsUsed: toolsUsed,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
      return AgentResult.failure(
        errorMessage: 'هەڵەیەک ڕوویدا: $e',
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      if (_state != AgentState.error &&
          _state != AgentState.failed &&
          _state != AgentState.cancelled &&
          _state != AgentState.completed) {
        _setState(AgentState.idle);
      }
    }
  }

  /// Fire-and-forget memory capture after a successful agent run.
  ///
  /// Wraps [onMemoryCapture] in try-catch so it can never turn a success
  /// into a failure. Does NOT await — the capture runs in the background.
  void _fireMemoryCapture(String userInput, AgentContext context) {
    if (onMemoryCapture == null) return;
    // Fire-and-forget: no await, errors swallowed.
    onMemoryCapture!(userInput, context).catchError((_) {});
  }

  // ── Step 23 orchestration seams ──
  // Expose the existing understand/planning logic without executing
  // the full AgentEngine.run() lifecycle. Step 23 owns the gates and
  // execution phases, so it must not call run() through the adapter.

  Future<AgentIntent> understandForOrchestration({
    required String userInput,
    required AgentContext context,
  }) {
    return _understand(userInput, context);
  }

  Future<AgentPlan> planForOrchestration({
    required String userInput,
    required AgentContext context,
  }) {
    return _planner.plan(
      userInput: userInput,
      context: context,
    );
  }

  // ── Understand Phase ──

  /// Send user input to AI with an intent-parsing prompt and
  /// parse the response into a structured AgentIntent.
  Future<AgentIntent> _understand(
    String userInput,
    AgentContext context,
  ) async {
    final intentPrompt =
        '''تۆ یارمەتدەرێکی زیرەکی بە کوردی سۆرانیت. تکایە مەبەستی بەکارهێنەر لەم دەقە شیبکەرەوە:

"$userInput"

لە وەڵامدا تکایە ئەم زانیاریانە بدە لە شێوەی JSON:
{
  "goal": "مەبەستێکی کورت",
  "actionType": "query|action|control|create|delete|conversation|ambiguous",
  "entities": [{"name": "ناو", "type": "جۆر", "value": "نرخ"}],
  "constraints": [],
  "toolRequirements": [],
  "expectedOutcome": "چی چاوەڕوان دەکرێت",
  "confirmationNeeded": false,
  "ambiguityReason": null,
  "confidence": 0.9,
  "originalUtterance": "$userInput"
}

تکایە تەنها JSON بگێڕەرەوە، هیچ شتێکی تر نەبێت.''';

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': intentPrompt},
      {'role': 'user', 'content': userInput},
    ];

    try {
      final aiResponse = await sendToAI(
        messages: messages,
        toolDefinitions: [],
        context: context,
      ).timeout(Duration(seconds: context.timeoutSeconds));

      final content = aiResponse['content'] as String? ?? '';
      return _parseIntentFromAI(content, userInput);
    } catch (e) {
      // If intent parsing fails, create a simple intent from the raw input.
      return AgentIntent(
        goal: userInput,
        actionType: IntentActionType.conversation,
        confidence: 0.5,
        originalUtterance: userInput,
      );
    }
  }

  /// Parse AI response content into an AgentIntent.
  AgentIntent _parseIntentFromAI(String content, String originalUtterance) {
    try {
      // Try to extract JSON from the AI response.
      String jsonStr = content.trim();

      // Remove markdown code fences if present.
      if (jsonStr.startsWith('```')) {
        final fenceEnd = jsonStr.indexOf('\n');
        if (fenceEnd > 0) {
          jsonStr = jsonStr.substring(fenceEnd + 1);
        }
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
        jsonStr = jsonStr.trim();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Parse action type.
      final actionTypeStr = json['actionType'] as String? ?? 'conversation';
      IntentActionType actionType;
      try {
        actionType = IntentActionType.values.firstWhere(
          (e) => e.name == actionTypeStr,
          orElse: () => IntentActionType.conversation,
        );
      } catch (_) {
        actionType = IntentActionType.conversation;
      }

      // Parse entities.
      final entities = <IntentEntity>[];
      final entityList = json['entities'] as List<dynamic>?;
      if (entityList != null) {
        for (final e in entityList) {
          if (e is Map<String, dynamic>) {
            entities.add(
              IntentEntity(
                name: e['name'] as String? ?? '',
                type: e['type'] as String? ?? '',
                value: e['value'] as String? ?? '',
                confidence: (e['confidence'] as num?)?.toDouble() ?? 1.0,
              ),
            );
          }
        }
      }

      return AgentIntent(
        goal: json['goal'] as String? ?? originalUtterance,
        actionType: actionType,
        entities: entities,
        constraints: (json['constraints'] as List<dynamic>?)
                ?.map((c) => c.toString())
                .toList() ??
            [],
        toolRequirements: (json['toolRequirements'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            [],
        expectedOutcome: json['expectedOutcome'] as String?,
        confirmationNeeded: json['confirmationNeeded'] as bool? ?? false,
        ambiguityReason: json['ambiguityReason'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        originalUtterance: originalUtterance,
      );
    } catch (e) {
      // JSON parsing failed — create a fallback intent.
      return AgentIntent(
        goal: content.isNotEmpty ? content : originalUtterance,
        actionType: IntentActionType.conversation,
        confidence: 0.5,
        originalUtterance: originalUtterance,
      );
    }
  }

  // ── Validate Phase ──

  /// Validate a plan — delegates to _planner.validatePlan().
  /// Returns null if valid, or an error message string if invalid.
  String? _validatePlan(AgentPlan plan, AgentContext context) {
    if (plan.isEmpty) return null; // Empty plan is valid (will use iterative loop).
    return _planner.validatePlan(plan, context);
  }

  // ── Observe Phase ──

  /// Create an AgentObservation from the step result and update context.
  AgentContext _observe(AgentStep step, AgentContext context) {
    final observation = AgentObservation(
      stepId: step.stepId,
      toolName: step.toolName,
      summary: step.status == AgentStepStatus.succeeded
          ? 'Step "${step.description}" completed successfully'
          : 'Step "${step.description}" failed: ${step.error}',
      relevance: step.status == AgentStepStatus.succeeded
          ? Relevance.high
          : Relevance.critical,
    );
    return context.addObservation(observation);
  }

  // ── Handle Failure ──

  /// Handle a failed step using recovery and replanning.
  ///
  /// 1. Calls AgentRecovery.decide() to get a RecoveryDecision.
  /// 2. Acts on the RecoveryStrategy:
  ///    - retry: the executor's retry loop already handles this
  ///    - retryWithModification: retry with modified arguments
  ///    - skip: mark step as skipped
  ///    - replan: call AgentReplanning.revise() to get a new plan
  ///    - abort: return with failure
  RecoveryDecision _handleFailure(
    AgentStep failedStep,
    AgentPlan currentPlan,
    AgentContext context,
    VerificationResult? verificationResult,
  ) {
    final decision = _recovery.decide(
      failedStep,
      context,
      verificationResult,
    );

    switch (decision.strategy) {
      case RecoveryStrategy.retry:
        // The executor's retry loop already handles retries.
        // If we got here, retries are exhausted — escalate.
        if (context.plan != null) {
          final replanResult = _replanning.revise(
            currentPlan,
            context,
            decision,
          );
          return RecoveryDecision(
            strategy: RecoveryStrategy.replan,
            reason: 'Retries exhausted — replanning: ${decision.reason}',
            newPlan: replanResult.revisedPlan,
            userMessage: decision.userMessage,
          );
        }
        return decision;

      case RecoveryStrategy.retryWithModification:
        // Apply modified arguments if provided.
        if (decision.modifiedArguments != null) {
          failedStep.recordRetry();
          failedStep.parameters = decision.modifiedArguments!;
        }
        return decision;

      case RecoveryStrategy.skip:
        failedStep.markSkipped(
          reason: decision.reason,
        );
        return decision;

      case RecoveryStrategy.replan:
        final replanResult = _replanning.revise(
          currentPlan,
          context,
          decision,
        );
        return RecoveryDecision(
          strategy: RecoveryStrategy.replan,
          reason: 'Replanning: ${decision.reason}',
          newPlan: replanResult.revisedPlan,
          userMessage: decision.userMessage ?? replanResult.reason,
        );

      case RecoveryStrategy.abort:
        return decision;
    }
  }

  // ── Iterative AI↔Tool Loop (Phase 1–3 fallback) ──

  /// The original Phase 1–3 iterative AI↔tool loop, used as fallback
  /// when LLM-guided planning returns an empty or invalid plan.
  Future<AgentResult> _runIterativeLoop({
    required String userInput,
    required AgentContext context,
    required Stopwatch stopwatch,
  }) async {
    final toolsUsed = <String>[];
    int stepsCompleted = 0;

    _setState(AgentState.planning);

    try {
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': context.agentConfig.systemPrompt},
        ...context.conversationHistory,
        {'role': 'user', 'content': userInput},
      ];

      final toolDefinitions = toolRegistry.openAISchemas;

      for (int iteration = 0; iteration < maxIterations; iteration++) {
        if (_cancellationToken.isCancelled) {
          _setState(AgentState.cancelled);
          stopwatch.stop();
          return AgentResult.failure(
            errorMessage: 'بەکارهێنەر هەڵوەشاندیەوە',
            stepsCompleted: stepsCompleted,
            toolsUsed: toolsUsed,
            executionTimeMs: stopwatch.elapsedMilliseconds,
          );
        }

        final aiResponse = await sendToAI(
          messages: messages,
          toolDefinitions: toolDefinitions,
          context: context,
        ).timeout(Duration(seconds: context.timeoutSeconds));

        final toolCalls = aiResponse['tool_calls'] as List<dynamic>?;
        final content = aiResponse['content'] as String?;

        if (toolCalls == null || toolCalls.isEmpty) {
          _setState(AgentState.responding);
          stopwatch.stop();
          _fireMemoryCapture(userInput, context);
          return AgentResult.success(
            response: content ?? '',
            stepsCompleted: stepsCompleted,
            toolsUsed: toolsUsed,
            executionTimeMs: stopwatch.elapsedMilliseconds,
          );
        }

        _setState(AgentState.executing);

        messages.add({
          'role': 'assistant',
          'content': content ?? '',
          'tool_calls': toolCalls,
        });

        for (final toolCall in toolCalls) {
          final tc = toolCall as Map<String, dynamic>;
          final funcMap = tc['function'] as Map<String, dynamic>?;
          final functionName =
              funcMap?['name'] as String? ?? tc['name'] as String?;
          final functionArgs =
              funcMap?['arguments'] as Map<String, dynamic>? ??
                  tc['arguments'] as Map<String, dynamic>? ?? {};
          final toolCallId = tc['id'] as String?;

          if (functionName == null) continue;

          if (!_planner.validateToolCall(functionName)) {
            final errorResult = ToolResult.failure(
              'Tool not registered: $functionName',
              errorCode: 'NOT_FOUND',
            );
            onToolResult?.call(functionName, errorResult);
            messages.add({
              'role': 'tool',
              'tool_call_id': toolCallId,
              'content': 'Error: Tool "$functionName" not found',
            });
            continue;
          }

          final args = ToolArguments(functionArgs);
          onToolCall?.call(functionName, args);

          final step = AgentStep(
            toolName: functionName,
            parameters: functionArgs,
            description: 'Executing $functionName',
          );
          onStepStart?.call(step);

          final result = await _executor.executeTool(
            toolName: functionName,
            arguments: functionArgs,
          );

          step.complete(result);
          onStepComplete?.call(step);
          onToolResult?.call(functionName, result);

          stepsCompleted++;
          toolsUsed.add(functionName);

          if (!result.isSuccess) {
            messages.add({
              'role': 'tool',
              'tool_call_id': toolCallId,
              'content': 'Error: ${result.errorMessage}',
            });
          } else {
            messages.add({
              'role': 'tool',
              'tool_call_id': toolCallId,
              'content':
                  result.data?.toString() ?? 'Tool completed successfully',
            });
          }
        }
      }

      // Exceeded max iterations — get one more AI response without tools.
      _setState(AgentState.responding);
      final finalResponse = await sendToAI(
        messages: messages,
        toolDefinitions: [],
        context: context,
      ).timeout(Duration(seconds: context.timeoutSeconds));

      stopwatch.stop();
      _fireMemoryCapture(userInput, context);
      return AgentResult.success(
        response: finalResponse['content'] as String? ??
            'ببورە، نەمتوانم وەڵام بدەمەوە. تکایە دووبارە هەوڵ بدەرەوە.',
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException catch (e) {
      _setState(AgentState.error);
      stopwatch.stop();
      // Route timeouts through AIErrorPresenter (stable token + errorCode)
      // instead of a hardcoded Kurdish string, so the UI shows a localized
      // message in the user's actual language (EN/KU) via the presenter.
      return AgentResult.failure(
        errorMessage: AIErrorPresenter.tokenFor(e),
        errorCode: AIErrorPresenter.tokenFor(e),
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      _setState(AgentState.error);
      stopwatch.stop();
      if (e is AIProviderException) {
        return AgentResult.failure(
          errorMessage: AIErrorPresenter.tokenFor(e),
          errorCode: AIErrorPresenter.tokenFor(e),
          stepsCompleted: stepsCompleted,
          toolsUsed: toolsUsed,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
      if (e is AgentFailure) {
        return AgentResult.failure(
          errorMessage: e.message,
          stepsCompleted: stepsCompleted,
          toolsUsed: toolsUsed,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
      return AgentResult.failure(
        errorMessage: 'هەڵەیەک ڕوویدا: $e',
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  bool _isClearlyConversational(String input) {
    final text = input.trim().toLowerCase();

    if (text.isEmpty) return false;

    const safePhrases = <String>[
      'سڵاو',
      'چۆنی',
      'چۆنیت',
      'باشیت',
      'کێیت',
      'تۆ کێیت',
      'ناوت چییە',
      'ناوت چیە',
      'چی دەکەیت',
      'چی دەکەی',
      'سوپاس',
      'دەستخۆش',
      'ڕۆژ باش',
      'شەو باش',
      'hello',
      'hi',
      'thanks',
      'thank you',
    ];

    for (final phrase in safePhrases) {
      if (text == phrase || text.startsWith('$phrase ')) {
        return true;
      }
    }

    return false;
  }

  // ── Direct AI Response ──

  /// Send a message to the AI without tools and get a text response.
  Future<String> _sendToAIDirectly(
    String message,
    AgentContext context,
  ) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': context.agentConfig.systemPrompt},
      ...context.conversationHistory,
      {'role': 'user', 'content': message},
    ];

    try {
      final aiResponse = await sendToAI(
        messages: messages,
        toolDefinitions: [],
        context: context,
      ).timeout(Duration(seconds: context.timeoutSeconds));

      return aiResponse['content'] as String? ?? '';
    } on AIProviderException {
      // Propagate provider errors so run()/_runIterativeLoop can map them to
      // a presentable error token instead of masking them behind a generic
      // Kurdish apology.
      rethrow;
    } catch (e) {
      return 'ببورە، نەمتوانم وەڵام بدەمەوە.';
    }
  }

  /// Cancels any ongoing execution.
  void cancel() {
    _cancellationToken.cancel();
    _setState(AgentState.cancelled);
  }
}
