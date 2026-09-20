/// tool_execution_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 22 ToolExecutionRepository
///
/// Exact signature match from Step 23.
/// This interface MUST be implemented by Step22ExecutionAdapter.
library;

/// Represents the result of a tool execution.
class ExecutionResult {
  final bool success;
  final Map<String, dynamic> data;
  final String? error;
  final Duration? executionTime;

  const ExecutionResult({
    this.success = false,
    this.data = const {},
    this.error,
    this.executionTime,
  });

  /// FAIL-CLOSED: default is not successful.
  bool get isSuccessful => success;
}

/// Abstract repository matching Step 23's ToolExecutionRepository.
/// execute({toolId, action, parameters, memoryContext, retryAttempt}) → ExecutionResult
/// cancel() → void
/// isAvailable() → bool
abstract class ToolExecutionRepository {
  Future<ExecutionResult> execute({
    required String toolId,
    required String action,
    required Map<String, dynamic> parameters,
    String? memoryContext,
    int retryAttempt = 0,
  });
  void cancel();
  bool isAvailable();
}
