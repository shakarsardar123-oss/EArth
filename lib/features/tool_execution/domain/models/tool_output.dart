/// tool_output.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Standardized output container for tool execution results.
/// Every tool must return a [ToolOutput] from its execute() method.
///
/// FAIL CLOSED: unknown states map to failClosed or denied.
library;

import 'package:meta/meta.dart';
import 'tool_input.dart';
import '../../../../core/errors/result.dart';

/// Status of a tool execution result.
enum ToolOutputStatus {
  success,
  failure,
  cancelled,
  timedOut,
  denied,
  failClosed,
  partial,
  empty;

  /// Whether this status represents a successful outcome.
  bool get isSuccess => this == success || this == partial || this == empty;

  /// Whether this status represents a failed outcome.
  bool get isFailure =>
      this == failure || this == cancelled || this == timedOut ||
      this == denied || this == failClosed;
}

/// Sensitive data categories for output classification.
enum SensitiveDataCategory {
  personalInfo,
  credentials,
  location,
  financial,
  health,
  biometric,
  communication,
}

/// Standardized output container for tool execution.
@immutable
class ToolOutput {
  /// The tool that produced this output.
  final String toolId;

  /// Status of the execution.
  final ToolOutputStatus status;

  /// Result data (non-null for success/partial, empty for others).
  final Map<String, dynamic> data;

  /// Human-readable message describing the result.
  final String? message;

  /// Error message (only for failure status).
  final String? errorMessage;

  /// Error code if applicable.
  final String? errorCode;

  /// Tool category.
  final String? toolCategory;

  /// Execution duration in milliseconds.
  final int? executionDurationMs;

  /// Current retry attempt (if this is a retry result).
  final int retryAttempt;

  /// Whether output contains sensitive data.
  final bool containsSensitiveData;

  /// Categories of sensitive data found.
  final List<SensitiveDataCategory> sensitiveCategories;

  /// Suggestions for the user (e.g., alternative actions).
  final List<String> suggestions;

  /// Partial result errors (only for partial status).
  final List<ToolInputValidationIssue> errors;

  /// Reason for denial/fail-closed.
  final String? reason;

  /// Timeout that was exceeded (only for timedOut status).
  final int? timeoutMs;

  const ToolOutput._({
    required this.toolId,
    required this.status,
    required this.data,
    this.message,
    this.errorMessage,
    this.errorCode,
    this.toolCategory,
    this.executionDurationMs,
    this.retryAttempt = 0,
    this.containsSensitiveData = false,
    this.sensitiveCategories = const [],
    this.suggestions = const [],
    this.errors = const [],
    this.reason,
    this.timeoutMs,
  });

  // ─── Factory constructors ──────────────────────────────────────

  /// Successful execution with result data.
  factory ToolOutput.success({
    required String toolId,
    required Map<String, dynamic> data,
    String? message,
    String? toolCategory,
    int? executionDurationMs,
    int retryAttempt = 0,
    List<String> suggestions = const [],
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.success,
        data: data,
        message: message,
        toolCategory: toolCategory,
        executionDurationMs: executionDurationMs,
        retryAttempt: retryAttempt,
        suggestions: suggestions,
      );

  /// Empty result — no data, but successful.
  factory ToolOutput.empty({
    required String toolId,
    String? message,
    String? toolCategory,
    int? executionDurationMs,
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.empty,
        data: const {},
        message: message,
        toolCategory: toolCategory,
        executionDurationMs: executionDurationMs,
      );

  /// Execution failure with error message.
  factory ToolOutput.failure({
    required String toolId,
    required String errorMessage,
    String? errorCode,
    String? toolCategory,
    int? executionDurationMs,
    int retryAttempt = 0,
    List<String> suggestions = const [],
    Map<String, dynamic> data = const {},
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.failure,
        data: data,
        errorMessage: errorMessage,
        errorCode: errorCode,
        toolCategory: toolCategory,
        executionDurationMs: executionDurationMs,
        retryAttempt: retryAttempt,
        suggestions: suggestions,
      );

  /// Execution was cancelled.
  factory ToolOutput.cancelled({
    required String toolId,
    String? message,
    String? toolCategory,
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.cancelled,
        data: const {},
        message: message ?? 'Execution cancelled',
        toolCategory: toolCategory,
      );

  /// Execution was denied by security/confirmation.
  factory ToolOutput.denied({
    required String toolId,
    required String reason,
    String? errorCode,
    String? toolCategory,
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.denied,
        data: const {},
        reason: reason,
        errorCode: errorCode,
        message: reason,
        toolCategory: toolCategory,
      );

  /// Execution timed out.
  factory ToolOutput.timedOut({
    required String toolId,
    required int timeoutMs,
    String? toolCategory,
    List<String> suggestions = const [],
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.timedOut,
        data: const {},
        timeoutMs: timeoutMs,
        message: 'Execution timed out after ${timeoutMs}ms',
        toolCategory: toolCategory,
        suggestions: suggestions,
      );

  /// Partial success — some data returned but with errors.
  factory ToolOutput.partial({
    required String toolId,
    required Map<String, dynamic> data,
    String? message,
    required List<ToolInputValidationIssue> errors,
    String? toolCategory,
    int? executionDurationMs,
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.partial,
        data: data,
        message: message,
        errors: errors,
        toolCategory: toolCategory,
        executionDurationMs: executionDurationMs,
      );

  /// FAIL CLOSED — unknown/unexpected state maps here.
  /// Any error or unavailable condition defaults to this.
  factory ToolOutput.failClosed({
    required String toolId,
    String? reason,
    String? toolCategory,
  }) =>
      ToolOutput._(
        toolId: toolId,
        status: ToolOutputStatus.failClosed,
        data: const {},
        reason: reason ?? 'Unknown state — execution blocked (fail-closed)',
        message: reason ?? 'Unknown state — execution blocked (fail-closed)',
        toolCategory: toolCategory,
      );

  // ─── Getters ──────────────────────────────────────────────────

  /// Whether this output represents a successful result.
  bool get isSuccess => status.isSuccess;

  /// Whether this output represents a failed result.
  bool get isFailure => status.isFailure;

  /// Whether this output contains data.
  bool get hasData => data.isNotEmpty;

  // ─── Copy-with ────────────────────────────────────────────────

  ToolOutput copyWith({
    String? toolId,
    ToolOutputStatus? status,
    Map<String, dynamic>? data,
    String? message,
    String? errorMessage,
    String? errorCode,
    String? toolCategory,
    int? executionDurationMs,
    int? retryAttempt,
    bool? containsSensitiveData,
    List<SensitiveDataCategory>? sensitiveCategories,
    List<String>? suggestions,
    List<ToolInputValidationIssue>? errors,
    String? reason,
    int? timeoutMs,
  }) =>
      ToolOutput._(
        toolId: toolId ?? this.toolId,
        status: status ?? this.status,
        data: data ?? this.data,
        message: message ?? this.message,
        errorMessage: errorMessage ?? this.errorMessage,
        errorCode: errorCode ?? this.errorCode,
        toolCategory: toolCategory ?? this.toolCategory,
        executionDurationMs:
            executionDurationMs ?? this.executionDurationMs,
        retryAttempt: retryAttempt ?? this.retryAttempt,
        containsSensitiveData:
            containsSensitiveData ?? this.containsSensitiveData,
        sensitiveCategories:
            sensitiveCategories ?? this.sensitiveCategories,
        suggestions: suggestions ?? this.suggestions,
        errors: errors ?? this.errors,
        reason: reason ?? this.reason,
        timeoutMs: timeoutMs ?? this.timeoutMs,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolOutput &&
          toolId == other.toolId &&
          status == other.status &&
          data == other.data;

  @override
  int get hashCode => Object.hash(toolId, status, data);

  @override
  String toString() =>
      'ToolOutput(tool: $toolId, status: $status, '
      'hasData: $hasData)';
}
