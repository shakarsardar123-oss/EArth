/// step22_execution_adapter.dart
/// AURA Assistant – Step 25: Infrastructure adapter for Step 22 Tool Execution.
///
/// Adapts Step 22's ToolExecution contract to Step 25's ToolExecutionRepository.
/// FAIL-CLOSED: no security/permission bypass.
///
/// Implements the EXACT ToolExecutionRepository interface:
///   execute({toolId, action, parameters, memoryContext, retryAttempt}) → Future<ExecutionResult>
///   cancel() → void
///   isAvailable() → bool
library;

import '../domain/repositories/tool_execution_repository.dart';

/// Adapter bridging Step 22 Tool Execution to Step 25's ToolExecutionRepository.
///
/// FAIL-CLOSED rules:
///   - Tool ID missing/empty → ExecutionResult(success: false)
///   - Action missing/empty → ExecutionResult(success: false)
///   - Adapter unavailable → ExecutionResult(success: false)
///   - NEVER bypasses security or permission checks
///   - cancel() is idempotent
class Step22ExecutionAdapter implements ToolExecutionRepository {
  bool _available;
  bool _cancelled;

  Step22ExecutionAdapter({bool available = true})
      : _available = available,
        _cancelled = false;

  @override
  Future<ExecutionResult> execute({
    required String toolId,
    required String action,
    required Map<String, dynamic> parameters,
    String? memoryContext,
    int retryAttempt = 0,
  }) async {
    // FAIL-CLOSED: unavailable → failure result
    if (!_available) {
      return const ExecutionResult(
        success: false,
        error: 'Tool execution unavailable — failing closed.',
      );
    }

    // FAIL-CLOSED: cancelled → failure result
    if (_cancelled) {
      return const ExecutionResult(
        success: false,
        error: 'Execution was cancelled.',
      );
    }

    // FAIL-CLOSED: empty toolId or action → failure
    if (toolId.isEmpty || action.isEmpty) {
      return const ExecutionResult(
        success: false,
        error: 'Missing toolId or action — failing closed.',
      );
    }

    // In production, delegates to Step 22's ToolExecutionProvider.
    // For structural validation, returns fail-closed result.
    return const ExecutionResult(
      success: false,
      error: 'No execution backend wired — failing closed.',
    );
  }

  @override
  void cancel() {
    _cancelled = true;
  }

  @override
  bool isAvailable() => _available;

  /// Reset cancellation state (for testing).
  void resetCancel() => _cancelled = false;

  /// Mark adapter as available (for wiring/testing).
  void setAvailable(bool available) => _available = available;
}
