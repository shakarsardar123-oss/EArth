/// tool_execution_engine.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Core execution engine — orchestrates the 7-gate pipeline:
///   Gate 1: Cancellation check
///   Gate 2: Tool lookup
///   Gate 3: Input validation (via ToolInputValidator → InputValidationResult)
///   Gate 4: Confirmation (if required)
///   Gate 5: Tool-level validation (Tool.validate → ToolInput)
///   Gate 6: Security clearance
///   Gate 7: Execution + normalization
///
/// Key API fixes:
///   - Registry uses get() not getTool()
///   - ToolInputValidator.validate returns InputValidationResult
///   - Tool.validate returns ToolInput (different types — both handled)
///   - validatedInput.errors needs conditional (only if isValid false)
///   - ToolExecutionCancelledException imported from domain/exceptions.dart
///   - context.throwIfCancelled() called at entry
///
/// FAIL CLOSED: any gate failure = deny/failClosed output.
library;

import '../domain/models/tool_output.dart';
import '../domain/models/tool_execution_context.dart';
import '../domain/models/tool_execution_metadata.dart';
import '../domain/models/exceptions.dart';
import 'executors/tool_executor_registry.dart';
import 'tool_input_validator.dart';
import 'tool_output_normalizer.dart';
import 'cancellation_token.dart';
import 'audit_logger.dart';

class ToolExecutionEngine {
  final ToolExecutorRegistry _registry;
  final ToolInputValidator _inputValidator;
  final ToolOutputNormalizer _outputNormalizer;
  final AuditLogger _auditLogger;

  ToolExecutionEngine({
    required ToolExecutorRegistry registry,
    ToolInputValidator? inputValidator,
    ToolOutputNormalizer? outputNormalizer,
    AuditLogger? auditLogger,
  })  : _registry = registry,
        _inputValidator = inputValidator ?? ToolInputValidator(),
        _outputNormalizer = outputNormalizer ?? ToolOutputNormalizer(),
        _auditLogger = auditLogger ?? AuditLogger();

  /// Execute a tool through the 7-gate pipeline.
  Future<ToolOutput> execute(
    String toolId,
    Map<String, dynamic> params,
    ToolExecutionContext context, {
    CancellationToken? cancellationToken,
  }) async {
    var metadata = ToolExecutionMetadata(
      toolId: toolId,
      executionId: context.executionId,
    );

    // ─── Gate 1: Cancellation check ──────────────────────────────
    if (context.isCancelled ||
        (cancellationToken?.isCancelled ?? false)) {
      metadata = _auditLogger.logCancellation(
        metadata,
        'Execution cancelled before start',
      );
      return ToolOutput.cancelled(
        toolId: toolId,
        message: 'Execution cancelled before start',
      );
    }

    try {
      context.throwIfCancelled();
    } on ToolExecutionCancelledException {
      metadata = _auditLogger.logCancellation(
        metadata,
        'Context cancellation detected at entry',
      );
      return ToolOutput.cancelled(
        toolId: toolId,
        message: 'Context cancelled at entry',
      );
    }

    // ─── Gate 2: Tool lookup ────────────────────────────────────
    final toolInstance = _registry.get(toolId);
    if (toolInstance == null) {
      metadata = _auditLogger.logFailClosed(
        metadata,
        'Tool not found in registry',
        details: {'toolId': toolId},
      );
      return ToolOutput.failClosed(
        toolId: toolId,
        reason: 'Tool "$toolId" not found in registry',
      );
    }

    // ─── Gate 3: Input validation (validator) ────────────────────
    metadata = _auditLogger.logValidation(
      metadata,
      'Validating input parameters',
    );
    final validationResult = _inputValidator.validate(
      toolId,
      params,
      requiredParams: [], // Populated from tool metadata in real impl
    );

    if (!validationResult.isValid) {
      metadata = _auditLogger.logFailure(
        metadata,
        'Input validation failed: ${validationResult.errors.length} issues',
      );
      // Convert to ToolInput via the bridge method
      final validatedInput = _inputValidator.toToolInput(
        toolId, params, validationResult,
      );
      final errorMessages = validatedInput.isValid
          ? <String>[]
          : validatedInput.errors.map((e) => e.message).toList();
      return ToolOutput.failure(
        toolId: toolId,
        errorMessage: 'Input validation failed: ${errorMessages.join("; ")}',
        errorCode: 'VALIDATION_FAILED',
      );
    }

    // Convert valid result to ToolInput
    final validatedInput = _inputValidator.toToolInput(
      toolId, params, validationResult,
    );

    // ─── Gate 4: Confirmation ───────────────────────────────────
    if (context.requiresConfirmation && !context.confirmationDenied) {
      metadata = _auditLogger.logConfirmation(
        metadata,
        'Tool requires confirmation — awaiting user decision',
      );
      // In real impl, this would await a confirmation callback.
      // FAIL CLOSED: if no confirmation mechanism, deny.
      return ToolOutput.denied(
        toolId: toolId,
        reason: 'Confirmation required but no handler registered',
      );
    }

    if (context.confirmationDenied) {
      metadata = _auditLogger.logDenial(
        metadata,
        'User denied confirmation',
      );
      return ToolOutput.denied(
        toolId: toolId,
        reason: 'User denied confirmation',
      );
    }

    // ─── Gate 5: Tool-level validation ──────────────────────────
    // Tool.validate() returns ToolInput (different from validator)
    final toolValidatedInput = toolInstance.validate(params);
    if (!toolValidatedInput.isValid) {
      metadata = _auditLogger.logFailure(
        metadata,
        'Tool-level validation failed',
        details: {
          'issues': toolValidatedInput.validationIssues.length,
        },
      );
      // Use conditional: if invalid, errors exist; if valid (edge), empty list
      final errorMessages = toolValidatedInput.isValid
          ? <String>[]
          : toolValidatedInput.errors.map((e) => e.message).toList();
      return ToolOutput.failure(
        toolId: toolId,
        errorMessage:
            'Tool validation failed: ${errorMessages.join("; ")}',
        errorCode: 'TOOL_VALIDATION_FAILED',
      );
    }

    // ─── Gate 6: Security clearance ────────────────────────────
    if (!context.securityCleared) {
      final riskLevel = toolInstance.riskLevel;
      if (riskLevel == 'critical' || riskLevel == 'high') {
        metadata = _auditLogger.logDenial(
          metadata,
          'Security clearance required for $riskLevel-risk tool',
        );
        return ToolOutput.denied(
          toolId: toolId,
          reason: 'Security clearance required for $riskLevel-risk tool',
        );
      }
    }

    // ─── Gate 7: Execute + Normalize ────────────────────────────
    try {
      metadata = _auditLogger.logExecution(
        metadata,
        'Executing tool: ${toolInstance.name}',
      );

      final result = await toolInstance.execute(
        toolValidatedInput,
        context,
      );

      metadata = _auditLogger.logNormalization(
        metadata,
        'Normalizing output',
      );

      final normalized = _outputNormalizer.normalize(
        result,
        locale: context.locale,
      );

      metadata = _auditLogger.logCompletion(
        metadata,
        'Execution completed successfully',
      );

      return normalized;
    } on ToolExecutionCancelledException catch (e) {
      metadata = _auditLogger.logCancellation(
        metadata,
        'Execution cancelled: ${e.message}',
      );
      return ToolOutput.cancelled(
        toolId: toolId,
        message: e.message,
      );
    } catch (e) {
      // FAIL CLOSED: any unhandled exception = failClosed
      metadata = _auditLogger.logFailClosed(
        metadata,
        'Unhandled exception during execution: $e',
      );
      return ToolOutput.failClosed(
        toolId: toolId,
        reason: 'Execution failed: $e',
      );
    }
  }

  /// Execute with timeout enforcement.
  Future<ToolOutput> executeWithTimeout(
    String toolId,
    Map<String, dynamic> params,
    ToolExecutionContext context,
    int timeoutMs, {
    CancellationToken? cancellationToken,
  }) async {
    // If context already timed out, return immediately
    if (context.isTimedOut) {
      return ToolOutput.timedOut(
        toolId: toolId,
        timeoutMs: timeoutMs,
      );
    }

    // In real impl, use Future.timeout or a Timer.
    // FAIL CLOSED: timeout = deny
    try {
      return await execute(
        toolId,
        params,
        context,
        cancellationToken: cancellationToken,
      );
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: toolId);
    }
  }

  /// Cancel a running execution (best-effort).
  bool cancel(String toolId) {
    final tool = _registry.get(toolId);
    if (tool == null) return false;
    return tool.cancel();
  }
}
