/// tool_execution_result.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Result of a tool execution attempt. Captures success/failure,
/// output data, failure details, and timing.
///
/// @immutable.
library;

import 'package:flutter/foundation.dart';
import 'package:aura_assistant/features/tool_registry/domain/models/tool_failure.dart';
import '../../../../core/errors/result.dart';

/// Outcome of a single tool execution.
@immutable
class ToolExecutionResult {
  /// The tool that was (attempted to be) executed.
  final String toolId;

  /// Whether execution succeeded.
  final bool success;

  /// Output data from the tool (if successful).
  final Map<String, dynamic> output;

  /// Failure details (if unsuccessful).
  final ToolFailure? failure;

  /// Wall-clock execution time in milliseconds.
  final int executionTimeMs;

  const ToolExecutionResult({
    required this.toolId,
    required this.success,
    this.output = const {},
    this.failure,
    this.executionTimeMs = 0,
  });

  /// Convenience factory for a successful execution.
  factory ToolExecutionResult.success({
    required String toolId,
    Map<String, dynamic> output = const {},
    int executionTimeMs = 0,
  }) =>
      ToolExecutionResult(
        toolId: toolId,
        success: true,
        output: output,
        executionTimeMs: executionTimeMs,
      );

  /// Convenience factory for a failed execution.
  factory ToolExecutionResult.failure({
    required String toolId,
    required ToolFailure failure,
    int executionTimeMs = 0,
  }) =>
      ToolExecutionResult(
        toolId: toolId,
        success: false,
        failure: failure,
        executionTimeMs: executionTimeMs,
      );

  @override
  String toString() =>
      'ToolExecutionResult(toolId: $toolId, success: $success, '
      'time: ${executionTimeMs}ms)';
}
