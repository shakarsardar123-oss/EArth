/// Step 23 — Tool Execution Adapter (WIRED)
///
/// Implements [ToolExecutionRepository] by delegating to the real Step 22
/// [AgentExecutor.executeTool]. The orchestrator NEVER executes a tool
/// directly — every call passes through the executor, which enforces the
/// full [ToolSecurityGate] pipeline (allowlist → argument sanitisation →
/// validation → security boundary → permission → risk → confirmation) and
/// FAIL-CLOSES when the gate is absent.
///
/// Type conversion happens ONLY at this boundary:
///   toolId/parameters → executeTool args;
///   core ToolResult (+ security error codes) → domain ExecutionResult.
///
/// FAIL-CLOSED: gate/permission/boundary blocks → denied; any other failure
/// → failed; error → failed.

import '../../../../core/agent/agent_executor.dart';
import '../../../../core/tools/tool_result.dart';
import '../../domain/orchestration_domain.dart';
import '../../../../core/errors/result.dart';

class ToolExecutionAdapter implements ToolExecutionRepository {
  /// The real Step 22 execution engine (injected, wired with the security
  /// gate). Same registry/gate the AgentEngine uses.
  final AgentExecutor _executor;

  /// Cancellation token shared with the executor.
  final CancellationToken _cancellationToken;

  ToolExecutionAdapter(this._executor, this._cancellationToken);

  /// Error codes emitted by the security pipeline that mean "denied"
  /// (as opposed to a genuine execution failure).
  static const Set<String> _deniedCodes = {
    'NOT_ALLOWED',
    'PERMISSION_DENIED',
    'CONFIRMATION_DENIED',
    'CONFIRMATION_NEEDED',
    'SECURITY_BOUNDARY',
    'SECURITY_GATE_MISSING',
    'SECURITY_GATE_BLOCKED',
    'PLATFORM_UNSUPPORTED',
    'INVALID_PACKAGE_NAME',
    'INVALID_SETTINGS_KEY',
    'DISALLOWED_URL_PROTOCOL',
  };

  @override
  Future<ExecutionResult> execute({
    required String toolId,
    required String action,
    required Map<String, dynamic> parameters,
    String? memoryContext,
    int retryAttempt = 0,
  }) async {
    try {
      if (_cancellationToken.isCancelled) {
        return ExecutionResult.cancelled(message: 'Cancelled before execution');
      }

      final ToolResult result = await _executor.executeTool(
        toolName: toolId,
        arguments: parameters,
      );

      if (result.isSuccess) {
        return ExecutionResult.success(
          outputData: result.data?.toString(),
        );
      }

      // Distinguish a security/permission denial from a plain failure.
      final code = result.errorCode;
      if (code != null && _deniedCodes.contains(code)) {
        return ExecutionResult.denied(
          reason: result.errorMessage ?? 'Execution denied ($code)',
        );
      }

      return ExecutionResult.failed(
        errorCode: code,
        errorMessage: result.errorMessage,
      );
    } catch (e) {
      // FAIL-CLOSED: error → failed.
      return ExecutionResult.failed(
        errorCode: 'EXECUTION_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<void> cancel() async {
    try {
      _cancellationToken.cancel();
    } catch (_) {
      // Cancellation must never throw.
    }
  }

  @override
  Future<bool> isAvailable() async => true;
}
