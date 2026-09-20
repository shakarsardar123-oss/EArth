import 'dart:async';

import 'agent_context.dart';
import 'agent_plan.dart';
import 'agent_result.dart';
import 'agent_step.dart';
import 'agent_step_status.dart';
import 'agent_state.dart';
import 'agent_verification_engine.dart';
import '../security/tool_security_gate.dart';
import '../security/confirmation_guard.dart';
import '../tools/tool_arguments.dart';
import '../tools/tool_registry.dart';
import '../tools/tool_result.dart';
import '../../core/errors/result.dart';

/// Cancellation token that can be used to abort execution mid-step.
class CancellationToken {
  bool _cancelled = false;

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelled;

  /// Request cancellation.
  void cancel() => _cancelled = true;

  /// Reset for reuse.
  void reset() => _cancelled = false;
}

/// Executes an agent plan step by step, invoking tools as needed.
///
/// Phase 4 enhancements:
/// - Permission validation before tool execution
/// - Confirmation flow integration
/// - Per-step retry with bounded budget
/// - Structured observation recording
/// - Cancellation support
/// - Verification after each step
class AgentExecutor {
  AgentExecutor({
    required this.toolRegistry,
    AgentVerificationEngine? verificationEngine,
    this.securityGate,
    this.onSecurityConfirmation,
    this.onStateChange,
    this.onStepStart,
    this.onStepComplete,
    this.onToolCall,
    this.onToolResult,
    this.onObservation,
    this.onConfirmationNeeded,
    this.cancellationToken,
  }) : verificationEngine = verificationEngine ?? AgentVerificationEngine();

  final ToolRegistry toolRegistry;

  /// Verification engine for checking step results.
  final AgentVerificationEngine verificationEngine;

  /// Optional security gate for tool-level permission and risk checks.
  final ToolSecurityGate? securityGate;

  /// Called when the security gate requires user confirmation.
  ///
  /// Receives the [ToolConfirmationRequest] and must return `true` if
  /// the user accepts, or `false` if they cancel.
  final Future<bool> Function(ToolConfirmationRequest request)?
      onSecurityConfirmation;

  /// Optional cancellation token.
  CancellationToken? cancellationToken;

  /// Called when the agent state changes.
  final void Function(AgentState state)? onStateChange;

  /// Called when a step starts executing.
  final void Function(AgentStep step)? onStepStart;

  /// Called when a step completes.
  final void Function(AgentStep step)? onStepComplete;

  /// Called when a tool is about to be invoked.
  final void Function(String toolName, ToolArguments args)? onToolCall;

  /// Called when a tool returns a result.
  final void Function(String toolName, ToolResult result)? onToolResult;

  /// Called when a structured observation is recorded.
  final void Function(AgentObservation observation)? onObservation;

  /// Called when confirmation is needed before a risky step.
  /// Returns true if confirmed, false if denied.
  final Future<bool> Function(AgentStep step, String message)?
      onConfirmationNeeded;

  /// Executes a single tool call by name with the given arguments.
  Future<ToolResult> executeTool({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    // Security check: is this tool allowed?
    if (!toolRegistry.isAllowed(toolName)) {
      return ToolResult.failure(
        'Tool "$toolName" is not allowed',
        errorCode: 'NOT_ALLOWED',
      );
    }

    final tool = toolRegistry.get(toolName);
    if (tool == null) {
      return ToolResult.failure(
        'Tool not found: $toolName',
        errorCode: 'NOT_FOUND',
      );
    }

    // Sanitize arguments.
    final sanitizedArgs = toolRegistry.sanitizeArguments(arguments);
    final toolArgs = ToolArguments(sanitizedArgs);

    // Validate arguments before execution.
    final validationError = tool.validateArguments(toolArgs);
    if (validationError != null) {
      return ToolResult.failure(validationError, errorCode: 'INVALID_ARGS');
    }

    // ── Security gate injection (Step 7) — FAIL CLOSED ──
    // If no security gate is wired, execution is refused rather than
    // silently allowed. Permission/risk/confirmation checks are mandatory.
    if (securityGate == null) {
      return ToolResult.failure(
        'Tool "$toolName" blocked: security gate is not configured. '
        'Tool execution is refused until the security gate is wired.',
        errorCode: 'SECURITY_GATE_MISSING',
      );
    }
    {
      final gateResult = await securityGate!.check(
        tool: tool,
        arguments: toolArgs,
      );

      if (gateResult.isAllowed) {
        // All security checks passed — proceed to execution.
      } else if (gateResult.confirmationRequest != null) {
        // Confirmation needed — ask the user.
        if (onSecurityConfirmation != null) {
          final accepted = await onSecurityConfirmation!(
            gateResult.confirmationRequest!,
          );
          if (accepted) {
            securityGate!.confirmationGuard.acceptPending();
            final postConfirm = securityGate!.checkAfterConfirmation(
              toolName: toolName,
              arguments: sanitizedArgs,
            );
            if (!postConfirm.isAllowed) {
              return securityGateResultToToolResult(postConfirm);
            }
          } else {
            securityGate!.confirmationGuard.cancelPending();
            return ToolResult.failure(
              gateResult.confirmationRequest!.message,
              errorCode: 'CONFIRMATION_DENIED',
            );
          }
        } else {
          // No handler — default to denial.
          securityGate!.confirmationGuard.cancelPending();
          return securityGateResultToToolResult(gateResult);
        }
      } else {
        // Blocked by gate (permission denied, boundary violation, etc.).
        return securityGateResultToToolResult(gateResult);
      }
    }

    onToolCall?.call(toolName, toolArgs);

    // Use the tool's own timeout if defined.
    final timeout = tool.definition.timeout;

    try {
      final result = await tool.execute(toolArgs).timeout(
            timeout,
            onTimeout: () => ToolResult.failure(
              'Tool "$toolName" timed out after ${timeout.inSeconds}s',
              errorCode: 'TIMEOUT',
            ),
          );

      onToolResult?.call(toolName, result);
      return result;
    } catch (e) {
      final result = ToolResult.failure(
        'Tool "$toolName" failed: $e',
        errorCode: 'EXECUTION_ERROR',
      );
      onToolResult?.call(toolName, result);
      return result;
    }
  }

  /// Execute a single step with retry, verification, and observation.
  Future<AgentStep> executeStep(
    AgentStep step,
    AgentContext context,
  ) async {
    step.markStarted();
    onStepStart?.call(step);

    // Check if confirmation is needed for this step.
    if (step.toolName.isNotEmpty) {
      final tool = toolRegistry.get(step.toolName);
      if (tool != null && tool.definition.needsConfirmation) {
        if (onConfirmationNeeded != null) {
          onStateChange?.call(AgentState.waitingForConfirmation);
          final confirmed = await onConfirmationNeeded!(
            step,
            'ئایا ڕێگە دەدەیت "${step.description}" بکرێت؟',
          );
          if (!confirmed) {
            step.markSkipped();
            onStepComplete?.call(step);
            return step;
          }
        }
      }
    }

    // Execute with retry loop.
    while (step.retryCount < step.maxRetries) {
      // Check for cancellation.
      if (cancellationToken?.isCancelled ?? false) {
        step.status = AgentStepStatus.failed;
        step.error = 'Cancelled by user';
        onStepComplete?.call(step);
        return step;
      }

      final result = await executeTool(
        toolName: step.toolName,
        arguments: step.parameters,
      );

      if (result.isSuccess) {
        step.complete(result);

        // Record observation.
        final observation = AgentObservation(
          stepId: step.stepId,
          toolName: step.toolName,
          summary: 'Step "${step.description}" completed successfully',
          relevance: Relevance.high,
        );
        context = context.addObservation(observation);
        onObservation?.call(observation);

        // Record tool call.
        final toolCallRecord = ToolCallRecord(
          stepId: step.stepId,
          toolName: step.toolName,
          parameters: step.parameters,
          result: result,
          success: result.isSuccess,
        );
        context = context.recordToolCall(toolCallRecord);

        // Verify the result.
        final verification = verificationEngine.verifyStep(step);
        if (!verification.passed &&
            verification.severity == VerificationSeverity.critical) {
          // Verification failed critically — don't mark as succeeded.
          step.status = AgentStepStatus.failed;
          step.error = verification.message ?? 'Verification failed';
        }

        onStepComplete?.call(step);
        return step;
      }

      // Step failed — try retry.
      step.recordRetry();
      context = context.incrementRetry();

      if (step.retryCount >= step.maxRetries) {
        break; // Exit retry loop.
      }

      // Brief delay before retry.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // All retries exhausted — mark as failed.
    final lastResult = step.result;
    if (lastResult != null && !lastResult.isSuccess) {
      step.error = lastResult.errorMessage;
    }
    step.status = AgentStepStatus.failed;

    // Record failure observation.
    final observation = AgentObservation(
      stepId: step.stepId,
      toolName: step.toolName,
      summary:
          'Step "${step.description}" failed after ${step.retryCount} retries',
      relevance: Relevance.high,
    );
    context = context.addObservation(observation);
    onObservation?.call(observation);

    onStepComplete?.call(step);
    return step;
  }

  /// Executes all steps in a plan with dependency-aware ordering.
  Future<AgentResult> executePlan({
    required AgentPlan plan,
    required AgentContext context,
  }) async {
    final stopwatch = Stopwatch()..start();
    final toolsUsed = <String>[];
    int stepsCompleted = 0;

    try {
      onStateChange?.call(AgentState.executing);

      for (final step in plan.steps) {
        // Check cancellation.
        if (cancellationToken?.isCancelled ?? false) {
          onStateChange?.call(AgentState.cancelled);
          return AgentResult.failure(
            errorMessage: 'Execution cancelled by user',
            stepsCompleted: stepsCompleted,
            toolsUsed: toolsUsed,
            executionTimeMs: stopwatch.elapsedMilliseconds,
          );
        }

        // Check step budget.
        if (stepsCompleted >= context.maxSteps) {
          return AgentResult.failure(
            errorMessage: 'Maximum steps (${context.maxSteps}) exceeded',
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
        if (!plan.areDependenciesMet(step)) {
          // Dependencies not met — skip this step.
          step.markSkipped();
          stepsCompleted++;
          continue;
        }

        // Execute the step.
        final executedStep = await executeStep(step, context);
        stepsCompleted++;

        if (executedStep.status == AgentStepStatus.failed) {
          // Step failed — check if we should continue or abort.
          onStateChange?.call(AgentState.error);
          return AgentResult.failure(
            errorMessage:
                'Tool "${executedStep.toolName}" failed: ${executedStep.error}',
            stepsCompleted: stepsCompleted,
            toolsUsed: toolsUsed,
            executionTimeMs: stopwatch.elapsedMilliseconds,
          );
        }

        toolsUsed.add(executedStep.toolName);
      }

      stopwatch.stop();
      onStateChange?.call(AgentState.responding);

      // Verify the entire plan.
      final planVerification = verificationEngine.verifyPlan(
        plan,
        context.observations,
      );
      if (!planVerification.passed &&
          planVerification.severity == VerificationSeverity.critical) {
        return AgentResult.failure(
          errorMessage: planVerification.message ?? 'Plan verification failed',
          stepsCompleted: stepsCompleted,
          toolsUsed: toolsUsed,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      return AgentResult.success(
        response: plan.steps.isEmpty
            ? null
            : plan.steps
                .where((s) => s.status == AgentStepStatus.succeeded)
                .last
                .result
                ?.data
                ?.toString(),
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException {
      onStateChange?.call(AgentState.error);
      return AgentResult.failure(
        errorMessage: 'Agent execution timed out',
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      onStateChange?.call(AgentState.error);
      return AgentResult.failure(
        errorMessage: 'Agent execution failed: $e',
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}
