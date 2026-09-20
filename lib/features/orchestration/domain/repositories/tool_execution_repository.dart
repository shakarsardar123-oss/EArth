import '../../../../core/errors/result.dart';
/// Step 23 — Tool Execution Repository Interface
///
/// Contract for the Step 22 Tool Execution Engine adapter.
/// The orchestrator never directly executes an arbitrary tool.
/// All execution must pass through the existing Step 20/22 security and execution pipeline.
///
/// Key Step 22 API contracts:
/// - ToolOutput.denied takes 'reason' NOT 'errorMessage'
/// - ToolOutput.cancelled takes 'message'
/// - ToolOutput.empty has NO data param
/// - ToolOutput.failure has optional 'data' as last param
/// - ToolExecutionContext.cancel() returns new context (immutable)
/// - CancellationToken.cancel() takes NO arguments
/// - Tool.riskLevel is String not enum
/// - All ToolOutput/ToolInput factories require toolId
/// - ToolOutputStatus uses 'failure' not 'failed'

abstract class ToolExecutionRepository {
  /// Execute a tool through the Step 22 pipeline.
  /// Returns ExecutionResult. Default/unknown = failed.
  Future<ExecutionResult> execute({
    required String toolId,
    required String action,
    required Map<String, dynamic> parameters,
    String? memoryContext,
    int retryAttempt = 0,
  });

  /// Cancel an ongoing execution.
  /// CancellationToken.cancel() takes NO arguments.
  Future<void> cancel();

  /// Whether the execution engine is available.
  Future<bool> isAvailable();
}

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
