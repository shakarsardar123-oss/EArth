/// Step 25 — Tool Execution Repository Interface
///
/// Contract for the Step 25 orchestration layer's tool execution adapter.
///
/// AUDIT FIX — Bug #11:
///   - Changed `cancel()→void` to `cancel()→Future<void>` (async per Step 23 contract)
///   - Changed `isAvailable()→bool` to `isAvailable()→Future<bool>` (async per Step 23 contract)
///   - Added `wasDenied(String toolId)→Future<bool>` method
///   - Added `wasCancelled(String toolId)→Future<bool>` method
///   - Added `wasDenied` and `wasCancelled` fields to ExecutionResult
///
///   Step 23 reference defines cancel and isAvailable as async,
///   and ExecutionResult includes wasDenied/wasCancelled fields.
///   The Step 25 version was out of sync — missing async signatures and
///   execution status query methods.
///   FAIL-CLOSED: default implementations deny.

/// Execution result — FAIL-CLOSED by default.
class ExecutionResult {
  final bool succeeded;
  final String? outputData;
  final String? errorCode;
  final String? errorMessage;
  final bool wasDenied;
  final bool wasCancelled;

  const ExecutionResult({
    this.succeeded = false,
    this.outputData,
    this.errorCode,
    this.errorMessage,
    this.wasDenied = false,
    this.wasCancelled = false,
  });

  factory ExecutionResult.success({String? outputData}) =>
      ExecutionResult(succeeded: true, outputData: outputData);

  factory ExecutionResult.denied({required String reason}) =>
      ExecutionResult(wasDenied: true, errorMessage: reason);

  factory ExecutionResult.cancelled({String? message}) =>
      ExecutionResult(wasCancelled: true, errorMessage: message);

  factory ExecutionResult.failed({String? errorCode, String? errorMessage}) =>
      ExecutionResult(errorCode: errorCode, errorMessage: errorMessage);
}

abstract class ToolExecutionRepository {
  /// Execute a tool through the execution pipeline.
  /// Returns ExecutionResult. FAIL-CLOSED: default/unknown = failed.
  Future<ExecutionResult> execute({
    required String toolId,
    required String action,
    required Map<String, dynamic> parameters,
    String? memoryContext,
  int retryAttempt = 0,
  });

  /// Cancel an ongoing execution.
  /// Async per Step 23 contract: CancellationToken.cancel() takes NO arguments.
  Future<void> cancel();

  /// Whether the execution engine is available.
  /// Async per Step 23 contract.
  Future<bool> isAvailable();

  /// Check whether a specific tool execution was denied.
  /// FAIL-CLOSED: if toolId not found or error occurs, return true (was denied).
  Future<bool> wasDenied(String toolId);

  /// Check whether a specific tool execution was cancelled.
  /// FAIL-CLOSED: if toolId not found or error occurs, return true (was cancelled).
  Future<bool> wasCancelled(String toolId);
}
