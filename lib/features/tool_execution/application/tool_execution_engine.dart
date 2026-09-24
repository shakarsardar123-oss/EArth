/// tool_execution_engine.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Central execution engine that orchestrates tool execution through
/// Step 20's 6-gate pipeline, bridges API mismatches, and adds:
/// - Tool interface dispatch (via Tool abstract class)
/// - Cancellation & timeout
/// - Retry integration with Step 18
/// - Security integration with Step 19
/// - Confirmation system enhancement
/// - Input validation & output normalization
/// - Audit logging
///
/// BRIDGES Step 20's API mismatches via adapter pattern:
/// - Abstract ToolExecutionGate.execute({toolId, params}) vs
///   concrete DefaultToolExecutionGate.execute(toolId, {parameters, context})
/// - Abstract ToolExecutor typedef vs concrete 3-arg executor
/// - Abstract canExecute(toolId) vs concrete checkReadiness(toolId)
/// - Abstract ToolSecurityAdapter.validateToolExecution() vs concrete .check()
/// - Abstract ToolDiscoveryApi methods vs DefaultToolDiscoveryApi methods
///
/// FAIL CLOSED: any gate failure, unknown state, or bridge error
/// results in denied/failed execution.
library;

import 'dart:async';

import 'package:aura_assistant/features/tool_registry/domain/models/tool_definition.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_execution_result.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_failure.dart';
import 'package:aura_assistant/features/tool_registry/application/tool_execution_gate.dart';
// TODO(CATEGORY B — Architecture Violation): Application layer should not import infrastructure implementations.
// These should depend on domain interfaces with infrastructure providing concrete implementations.
// See: tool_registry/infrastructure/default_tool_execution_gate.dart, default_tool_confirmation_service.dart
import 'package:aura_assistant/features/tool_registry/infrastructure/default_tool_execution_gate.dart';
import 'package:aura_assistant/features/tool_registry/infrastructure/default_tool_confirmation_service.dart';

import '../domain/models/tool_execution_context.dart';
import '../domain/models/tool_input.dart';
import '../domain/models/tool_output.dart';
import '../domain/models/tool_execution_metadata.dart';
import '../domain/services/tool_interface.dart';
// TODO(CATEGORY B — Architecture Violation): Application layer should not import infrastructure implementations.
// These should depend on domain interfaces with infrastructure providing concrete implementations.
import '../infrastructure/adapters/step20_gate_adapter.dart';
import '../infrastructure/adapters/step19_security_bridge.dart';
import '../infrastructure/adapters/step18_retry_bridge.dart';
import '../infrastructure/executors/tool_executor_registry.dart';
import 'cancellation_token.dart';
import 'tool_input_validator.dart';
import 'tool_output_normalizer.dart';
import '../../../core/errors/result.dart';

/// Result of a full tool execution attempt through the engine.
class EngineExecutionResult {
  final ToolOutput output;
  final ToolExecutionMetadata metadata;

  const EngineExecutionResult({
    required this.output,
    required this.metadata,
  });

  bool get isSuccess => output.isSuccess;
  bool get isFailure => output.isFailure;
}

/// Central tool execution engine.
///
/// Orchestrates execution through:
/// 1. Gate pipeline (bridged from Step 20)
/// 2. Security check (bridged from Step 19)
/// 3. Confirmation (bridged from Step 20)
/// 4. Input validation
/// 5. Tool dispatch (via Tool interface)
/// 6. Output normalization
/// 7. Retry/recovery (bridged from Step 18)
/// 8. Audit logging
///
/// Every gate is FAIL CLOSED — any failure stops the pipeline.
class ToolExecutionEngine {
  // ─── Dependencies ─────────────────────────────────────────────────

  /// Step 20 gate adapter (bridges API mismatches).
  final Step20GateAdapter _gateAdapter;

  /// Step 19 security bridge.
  final Step19SecurityBridge _securityBridge;

  /// Step 18 retry bridge.
  final Step18RetryBridge _retryBridge;

  /// Tool executor registry (maps toolId → Tool instance).
  final ToolExecutorRegistry _executorRegistry;

  /// Input validator.
  final ToolInputValidator _inputValidator;

  /// Output normalizer.
  final ToolOutputNormalizer _outputNormalizer;

  /// Confirmation service adapter.
  final Step20ConfirmationAdapter _confirmationAdapter;

  /// Audit log sink.
  final void Function(AuditEntry entry)? _auditSink;

  /// Active cancellations (executionId → CancellationToken).
  final Map<String, CancellationToken> _activeCancellations = {};

  /// Active metadata tracking (executionId → metadata).
  final Map<String, ToolExecutionMetadata> _activeMetadata = {};

  ToolExecutionEngine({
    required Step20GateAdapter gateAdapter,
    required Step19SecurityBridge securityBridge,
    required Step18RetryBridge retryBridge,
    required ToolExecutorRegistry executorRegistry,
    required ToolInputValidator inputValidator,
    required ToolOutputNormalizer outputNormalizer,
    required Step20ConfirmationAdapter confirmationAdapter,
    void Function(AuditEntry entry)? auditSink,
  })  : _gateAdapter = gateAdapter,
        _securityBridge = securityBridge,
        _retryBridge = retryBridge,
        _executorRegistry = executorRegistry,
        _inputValidator = inputValidator,
        _outputNormalizer = outputNormalizer,
        _confirmationAdapter = confirmationAdapter,
        _auditSink = auditSink;

  // ─── Public API ───────────────────────────────────────────────────

  /// Execute a tool through the full pipeline.
  ///
  /// This is the main entry point for all tool executions.
  /// It runs through all 6 gates, validation, confirmation,
  /// dispatch, normalization, and retry.
  ///
  /// Returns [EngineExecutionResult] containing the output and metadata.
  Future<EngineExecutionResult> execute(
    String toolId,
    Map<String, dynamic> params, {
    String caller = 'user',
    String? memoryContext,
    int timeoutMs = 30000,
    int maxRetries = 3,
    bool isBackground = false,
    String locale = 'ku',
  }) async {
    final executionId = _generateExecutionId();
    final context = ToolExecutionContext(
      executionId: executionId,
      toolId: toolId,
      caller: caller,
      memoryContext: memoryContext,
      timeoutMs: timeoutMs,
      maxRetries: maxRetries,
      isBackground: isBackground,
      locale: locale,
    );

    final metadata = ToolExecutionMetadata(
      executionId: executionId,
      toolId: toolId,
      caller: caller,
      requestedAt: DateTime.now(),
    );
    _activeMetadata[executionId] = metadata;

    _audit('engine_start', 'Execution requested for tool: $toolId');

    try {
      return await _executeWithRetry(context, params, metadata);
    } finally {
      _activeCancellations.remove(executionId);
      _activeMetadata.remove(executionId);
    }
  }

  /// Request cancellation of an active execution.
  bool cancelExecution(String executionId) {
    final token = _activeCancellations[executionId];
    if (token != null && !token.isCancelled) {
      token.cancel();
      _audit('cancel', 'Cancellation requested for: $executionId');
      return true;
    }
    final metadata = _activeMetadata[executionId];
    if (metadata != null) {
      // Try to cancel via the tool instance
      final tool = _executorRegistry.get(metadata.toolId);
      if (tool != null && tool.isExecuting) {
        final cancelled = tool.cancel();
        _audit('cancel_tool', 'Tool cancel for $executionId: $cancelled');
        return cancelled;
      }
    }
    return false;
  }

  /// Get metadata for an active execution.
  ToolExecutionMetadata? getMetadata(String executionId) =>
      _activeMetadata[executionId];

  // ─── Internal pipeline ─────────────────────────────────────────────

  /// Execute with retry support (bridges Step 18).
  Future<EngineExecutionResult> _executeWithRetry(
    ToolExecutionContext context,
    Map<String, dynamic> params,
    ToolExecutionMetadata metadata,
  ) async {
    var currentContext = context;
    var currentMetadata = metadata;

    for (var attempt = 0; attempt <= currentContext.maxRetries; attempt++) {
      if (attempt > 0) {
        // Check if retry is possible via Step 18 bridge
        final canRetry = _retryBridge.canRetry(
          toolId: currentContext.toolId,
          currentAttempt: attempt,
          maxRetries: currentContext.maxRetries,
        );
        if (!canRetry) {
          _audit('retry_exhausted',
              'No more retries for ${currentContext.toolId}');
          break;
        }

        // Wait for backoff delay
        final delayMs = _retryBridge.getBackoffDelay(attempt);
        await Future.delayed(Duration(milliseconds: delayMs));

        currentContext = currentContext.incrementRetry();
        currentMetadata = currentMetadata.copyWith(
          retryAttempt: attempt,
          phase: ToolExecutionPhase.requested,
        );

        _audit('retry', 'Retry attempt $attempt for ${currentContext.toolId}');
      }

      final result = await _executeSingleAttempt(
        currentContext,
        params,
        currentMetadata.copyWith(retryAttempt: attempt),
      );

      if (result.output.isSuccess) {
        return result;
      }

      // Check if the failure is retryable
      final failurePhase = _retryBridge.classifyFailure(
        result.output.errorCode ?? 'unknown',
        result.output.errorMessage ?? '',
      );
      if (!_retryBridge.isRetryablePhase(failurePhase)) {
        _audit('non_retryable',
            'Failure is not retryable: ${result.output.errorCode}');
        return result;
      }

      currentMetadata = result.metadata;
    }

    // All retries exhausted — return last failure
    return EngineExecutionResult(
      output: ToolOutput.failure(
        toolId: currentContext.toolId,
        errorMessage: 'All retry attempts exhausted',
        errorCode: 'RETRY_EXHAUSTED',
        retryAttempt: currentContext.retryAttempt,
      ),
      metadata: currentMetadata.copyWith(
        phase: ToolExecutionPhase.failed,
        completedAt: DateTime.now(),
        errorCode: 'RETRY_EXHAUSTED',
        errorMessage: 'All retry attempts exhausted',
      ),
    );
  }

  /// Execute a single attempt through the full pipeline.
  Future<EngineExecutionResult> _executeSingleAttempt(
    ToolExecutionContext context,
    Map<String, dynamic> params,
    ToolExecutionMetadata metadata,
  ) async {
    var currentMetadata = metadata;

    // ─── Gate 1: Registry check (bridged) ────────────────────────────
    currentMetadata = currentMetadata.withPhase(ToolExecutionPhase.validating);
    final registryResult = _gateAdapter.isToolRegistered(context.toolId);
    if (!registryResult) {
      _audit('gate1_fail', 'Tool not registered: ${context.toolId}');
      return _failClosed(context, currentMetadata, 'Tool not registered');
    }
    currentMetadata = currentMetadata.withGatePassed();

    // ─── Gate 2: Security check (bridged from Step 19) ───────────────
    final securityVerdict = _securityBridge.checkTool(context.toolId);
    if (!securityVerdict.allowed) {
      currentMetadata = currentMetadata.copyWith(
        securityVerdict: securityVerdict.displayReason,
      );
      _audit('gate2_fail', 'Security denied: ${securityVerdict.displayReason}');
      return EngineExecutionResult(
        output: ToolOutput.denied(
          toolId: context.toolId,
          reason: securityVerdict.reason ?? 'Security check failed',
          errorCode: securityVerdict.isFailClosedDenial
              ? 'FAIL_CLOSED_SECURITY'
              : 'SECURITY_DENIED',
        ),
        metadata: currentMetadata.copyWith(
          phase: ToolExecutionPhase.denied,
          completedAt: DateTime.now(),
        ),
      );
    }
    currentMetadata = currentMetadata.copyWith(
      securityVerdict: securityVerdict.displayReason,
    ).withGatePassed();

    // ─── Gate 3: Permission check (bridged) ───────────────────────────
    final permResult = _gateAdapter.checkPermissions(context.toolId);
    if (!permResult) {
      _audit('gate3_fail', 'Permission denied for: ${context.toolId}');
      return EngineExecutionResult(
        output: ToolOutput.denied(
          toolId: context.toolId,
          reason: 'Permission check failed',
          errorCode: 'PERMISSION_DENIED',
        ),
        metadata: currentMetadata.copyWith(
          phase: ToolExecutionPhase.denied,
          completedAt: DateTime.now(),
        ),
      );
    }
    currentMetadata = currentMetadata.withGatePassed();

    // ─── Gate 4: Confirmation (bridged from Step 20) ─────────────────
    if (context.requiresConfirmation ||
        _gateAdapter.requiresConfirmation(context.toolId)) {
      currentMetadata = currentMetadata
          .withPhase(ToolExecutionPhase.confirming);
      final confirmed = await _confirmationAdapter.requestConfirmation(
        context.toolId,
        message: 'Confirm execution of ${context.toolId}?',
      );
      currentMetadata = currentMetadata.copyWith(
        confirmationResult: confirmed ? 'confirmed' : 'denied',
      );
      if (!confirmed) {
        _audit('gate4_fail', 'User denied confirmation for: ${context.toolId}');
        return EngineExecutionResult(
          output: ToolOutput.denied(
            toolId: context.toolId,
            reason: 'User denied confirmation',
            errorCode: 'CONFIRMATION_DENIED',
          ),
          metadata: currentMetadata.copyWith(
            phase: ToolExecutionPhase.denied,
            completedAt: DateTime.now(),
          ),
        );
      }
    }
    currentMetadata = currentMetadata.withGatePassed();

    // ─── Gate 5: Input validation ────────────────────────────────────
    currentMetadata = currentMetadata.withPhase(ToolExecutionPhase.sanitizing);
    final toolInstance = _executorRegistry.get(context.toolId);
    final validatedInput = toolInstance != null
        ? toolInstance.validate(params)
        : _inputValidator.validate(context.toolId, params);
    currentMetadata = currentMetadata.copyWith(
      validationResult: validatedInput.isValid ? 'valid' : 'invalid',
    );
    if (!validatedInput.isValid) {
      _audit('gate5_fail',
          'Input validation failed: ${validatedInput.errors.map((e) => e.message)}');
      return EngineExecutionResult(
        output: ToolOutput.failure(
          toolId: context.toolId,
          errorMessage: 'Input validation failed: '
              '${validatedInput.errors.map((e) => "${e.field}: ${e.message}").join(", ")}',
          errorCode: 'INVALID_INPUT',
        ),
        metadata: currentMetadata.copyWith(
          phase: ToolExecutionPhase.failed,
          completedAt: DateTime.now(),
        ),
      );
    }
    currentMetadata = currentMetadata.withGatePassed();

    // ─── Gate 6: Readiness check (bridged) ───────────────────────────
    final readiness = await _gateAdapter.checkReadiness(context.toolId);
    if (!readiness) {
      _audit('gate6_fail', 'Tool not ready: ${context.toolId}');
      return _failClosed(context, currentMetadata, 'Tool not ready');
    }
    currentMetadata = currentMetadata.withGatePassed();

    // ─── All gates passed — execute ──────────────────────────────────
    currentMetadata = currentMetadata.withPhase(ToolExecutionPhase.executing);

    // Set up cancellation and timeout
    final cancellationToken = CancellationToken();
    _activeCancellations[context.executionId] = cancellationToken;

    final updatedContext = context.copyWith(
      securityCleared: true,
      securityReason: securityVerdict.reason,
    );

    ToolOutput output;
    try {
      if (context.hasTimeout) {
        output = await _executeWithTimeout(
          toolInstance!,
          validatedInput,
          updatedContext,
          cancellationToken,
          Duration(milliseconds: context.timeoutMs),
        );
      } else {
        output = await toolInstance!
            .execute(validatedInput, updatedContext);
      }
    } on ToolExecutionCancelledException {
      output = ToolOutput.cancelled(
        toolId: context.toolId,
        message: 'Execution was cancelled',
      );
    } catch (e) {
      output = ToolOutput.failClosed(
        toolId: context.toolId,
        reason: 'Unexpected error: $e',
      );
    }

    // ─── Normalize output ────────────────────────────────────────────
    currentMetadata = currentMetadata.withPhase(ToolExecutionPhase.normalizing);
    final normalizedOutput = _outputNormalizer.normalize(output);

    // ─── Complete ────────────────────────────────────────────────────
    final finalMetadata = currentMetadata.withCompletion(
      errorCode: normalizedOutput.isFailure ? normalizedOutput.errorCode : null,
      errorMessage:
          normalizedOutput.isFailure ? normalizedOutput.errorMessage : null,
    );

    _audit('engine_complete',
        'Execution completed: ${normalizedOutput.status.displayName}');

    return EngineExecutionResult(
      output: normalizedOutput,
      metadata: finalMetadata.copyWith(
        isBackground: context.isBackground,
        isVoiceInitiated: context.caller == 'voice',
      ),
    );
  }

  // ─── Timeout execution wrapper ─────────────────────────────────────

  Future<ToolOutput> _executeWithTimeout(
    Tool tool,
    ToolInput input,
    ToolExecutionContext context,
    CancellationToken cancellationToken,
    Duration timeout,
  ) async {
    final completer = Completer<ToolOutput>();

    // Timeout timer
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        cancellationToken.cancel();
        completer.complete(ToolOutput.timedOut(
          toolId: context.toolId,
          timeoutMs: context.timeoutMs,
          suggestions: ['Increase timeout or simplify parameters'],
        ));
      }
    });

    // Cancellation check
    cancellationToken.onCancel(() {
      if (!completer.isCompleted) {
        completer.complete(ToolOutput.cancelled(
          toolId: context.toolId,
          message: 'Execution cancelled',
        ));
      }
    });

    // Actual execution
    try {
      final result = await tool.execute(input, context);
      if (!completer.isCompleted) {
        timer.cancel();
        completer.complete(result);
      }
    } catch (e) {
      if (!completer.isCompleted) {
        timer.cancel();
        completer.complete(ToolOutput.failClosed(
          toolId: context.toolId,
          reason: 'Execution error: $e',
        ));
      }
    }

    return completer.future;
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  EngineExecutionResult _failClosed(
    ToolExecutionContext context,
    ToolExecutionMetadata metadata,
    String reason,
  ) =>
      EngineExecutionResult(
        output: ToolOutput.failClosed(
          toolId: context.toolId,
          reason: reason,
        ),
        metadata: metadata.copyWith(
          phase: ToolExecutionPhase.failClosed,
          completedAt: DateTime.now(),
          errorCode: 'FAIL_CLOSED',
          errorMessage: reason,
        ),
      );

  void _audit(String action, String description) {
    final entry = AuditEntry(
      action: action,
      description: description,
      timestamp: DateTime.now(),
    );
    _auditSink?.call(entry);
  }

  String _generateExecutionId() =>
      'exec_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  static int _idCounter = 0;
}

/// Exception thrown when execution is cancelled.
class ToolExecutionCancelledException implements Exception {
  final String message;
  const ToolExecutionCancelledException([this.message = 'Execution cancelled']);

  @override
  String toString() => 'ToolExecutionCancelledException: $message';
}
