/// tool_input.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Validated input container for tool execution.
/// Encapsulates raw params, sanitized params, and any validation issues.
///
/// FAIL CLOSED: any unknown/missing param produces an error-level issue.
library;

import 'package:meta/meta.dart';

/// Severity levels for input validation issues.
enum ToolInputValidationSeverity {
  error,
  warning,
  info;

  /// Whether this severity level blocks execution.
  bool get blocksExecution => this == error;
}

/// A single validation issue found in tool input.
@immutable
class ToolInputValidationIssue {
  final String field;
  final String message;
  final ToolInputValidationSeverity severity;

  const ToolInputValidationIssue({
    required this.field,
    required this.message,
    this.severity = ToolInputValidationSeverity.error,
  });

  @override
  String toString() =>
      'ToolInputValidationIssue($field: $message [$severity])';
}

/// Validated input container for tool execution.
///
/// Use [ToolInput.valid] for valid input and [ToolInput.invalid] for
/// input that failed validation.
@immutable
class ToolInput {
  /// The tool this input is for.
  final String toolId;

  /// Original raw parameters before sanitization.
  final Map<String, dynamic> rawParams;

  /// Parameters after sanitization (may be empty if invalid).
  final Map<String, dynamic> sanitizedParams;

  /// Validation issues found (empty if valid).
  final List<ToolInputValidationIssue> validationIssues;

  /// Whether the input passed validation.
  final bool isValid;

  /// Whether the params were sanitized (modified from raw).
  final bool wasSanitized;

  /// Source of this input (user, voice, agent, system).
  final String source;

  const ToolInput._({
    required this.toolId,
    required this.rawParams,
    required this.sanitizedParams,
    required this.validationIssues,
    required this.isValid,
    this.wasSanitized = false,
    this.source = 'user',
  });

  /// Create valid input — params become both raw and sanitized.
  factory ToolInput.valid({
    required String toolId,
    required Map<String, dynamic> params,
    bool wasSanitized = false,
    String source = 'user',
  }) =>
      ToolInput._(
        toolId: toolId,
        rawParams: Map.unmodifiable(params),
        sanitizedParams: Map.unmodifiable(params),
        validationIssues: const [],
        isValid: true,
        wasSanitized: wasSanitized,
        source: source,
      );

  /// Create invalid input with a single validation issue.
  factory ToolInput.invalid({
    required String toolId,
    required Map<String, dynamic> rawParams,
    required String field,
    required String message,
    String source = 'user',
  }) =>
      ToolInput._(
        toolId: toolId,
        rawParams: Map.unmodifiable(rawParams),
        sanitizedParams: const {},
        validationIssues: [
          ToolInputValidationIssue(
            field: field,
            message: message,
            severity: ToolInputValidationSeverity.error,
          ),
        ],
        isValid: false,
        wasSanitized: false,
        source: source,
      );

  /// Create input with multiple validation issues.
  factory ToolInput.withIssues({
    required String toolId,
    required Map<String, dynamic> rawParams,
    required List<ToolInputValidationIssue> issues,
    Map<String, dynamic>? sanitizedParams,
    bool wasSanitized = false,
    String source = 'user',
  }) =>
      ToolInput._(
        toolId: toolId,
        rawParams: Map.unmodifiable(rawParams),
        sanitizedParams:
            Map.unmodifiable(sanitizedParams ?? const {}),
        validationIssues: List.unmodifiable(issues),
        isValid: issues.every((i) => !i.severity.blocksExecution),
        wasSanitized: wasSanitized,
        source: source,
      );

  /// Error-level issues only.
  List<ToolInputValidationIssue> get errors =>
      validationIssues
          .where((i) => i.severity == ToolInputValidationSeverity.error)
          .toList();

  /// Warning-level issues only.
  List<ToolInputValidationIssue> get warnings =>
      validationIssues
          .where((i) => i.severity == ToolInputValidationSeverity.warning)
          .toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolInput &&
          toolId == other.toolId &&
          rawParams == other.rawParams &&
          isValid == other.isValid;

  @override
  int get hashCode => Object.hash(toolId, rawParams, isValid);

  @override
  String toString() =>
      'ToolInput(tool: $toolId, valid: $isValid, '
      'issues: ${validationIssues.length})';
}
