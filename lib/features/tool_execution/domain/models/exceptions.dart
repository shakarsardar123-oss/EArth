/// exceptions.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Canonical exception types for the tool execution system.
/// Consolidated from previous duplicate definitions in
/// cancellation_token.dart and tool_execution_engine.dart.
///
/// FAIL CLOSED: any unhandled exception is treated as denial.
library;

/// Exception thrown when a tool execution is cancelled.
///
/// This is the single canonical definition used across all
/// executors, the engine, and the cancellation subsystem.
class ToolExecutionCancelledException implements Exception {
  /// Human-readable reason for the cancellation.
  final String message;

  /// Optional tool ID that was cancelled.
  final String? toolId;

  /// Optional execution ID that was cancelled.
  final String? executionId;

  const ToolExecutionCancelledException(
    this.message, {
    this.toolId,
    this.executionId,
  });

  @override
  String toString() =>
      'ToolExecutionCancelledException: $message'
      '${toolId != null ? ' (tool: $toolId)' : ''}'
      '${executionId != null ? ' (exec: $executionId)' : ''}';
}
