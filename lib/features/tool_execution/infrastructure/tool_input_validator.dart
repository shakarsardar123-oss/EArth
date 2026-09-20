/// tool_input_validator.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Input validation and sanitization engine.
/// Uses ToolInput.valid / ToolInput.invalid factory constructors.
/// Returns InputValidationResult (not ToolInput) from validate().
///
/// FAIL CLOSED: any suspicious input is rejected or sanitized.
library;

import '../domain/models/tool_input.dart';

/// Result of input validation by the validator.
class InputValidationResult {
  /// Whether the input passed validation.
  final bool isValid;

  /// Error-level validation issues.
  final List<ToolInputValidationIssue> errors;

  /// Sanitized parameters (safe to use even if invalid).
  final Map<String, dynamic> sanitizedParams;

  /// Whether the params were modified during sanitization.
  final bool wasSanitized;

  const InputValidationResult({
    required this.isValid,
    this.errors = const [],
    this.sanitizedParams = const {},
    this.wasSanitized = false,
  });

  /// Whether any injection patterns were detected.
  bool get hasInjection =>
      errors.any((e) => e.field == 'injection');

  /// Whether any errors were found.
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'InputValidationResult(valid: $isValid, '
      'errors: ${errors.length}, sanitized: $wasSanitized)';
}

/// Input validation and sanitization engine.
///
/// Validates raw tool parameters against the tool's contract:
/// 1. Type checking
/// 2. Range validation
/// 3. Injection detection
/// 4. Required parameter verification
/// 5. Sanitization (removes dangerous values)
class ToolInputValidator {
  /// Perform validation on raw parameters.
  ///
  /// Returns [InputValidationResult] (not ToolInput).
  /// The engine is responsible for converting this to ToolInput
  /// via ToolInput.valid or ToolInput.invalid.
  InputValidationResult validate(
    String toolId,
    Map<String, dynamic> rawParams, {
    List<String> requiredParams = const [],
    Map<String, String> paramTypes = const {},
    Map<String, List<double>> paramRanges = const {},
  }) {
    final issues = <ToolInputValidationIssue>[];
    final sanitized = Map<String, dynamic>.from(rawParams);
    var wasModified = false;

    // Gate 1: Required parameter check
    for (final param in requiredParams) {
      if (!rawParams.containsKey(param) || rawParams[param] == null) {
        issues.add(ToolInputValidationIssue(
          field: param,
          message: 'Required parameter "$param" is missing',
          severity: ToolInputValidationSeverity.error,
        ));
      }
    }

    // Gate 2: Type checking
    for (final entry in paramTypes.entries) {
      final field = entry.key;
      final expectedType = entry.value;
      if (rawParams.containsKey(field) && rawParams[field] != null) {
        final actualType = _typeOf(rawParams[field]);
        if (actualType != expectedType) {
          issues.add(ToolInputValidationIssue(
            field: field,
            message: 'Expected type $expectedType but got $actualType',
            severity: ToolInputValidationSeverity.warning,
          ));
          sanitized.remove(field);
          wasModified = true;
        }
      }
    }

    // Gate 3: Range validation
    for (final entry in paramRanges.entries) {
      final field = entry.key;
      final range = entry.value;
      if (rawParams.containsKey(field) && rawParams[field] is num) {
        final value = rawParams[field] as num;
        if (value < range[0] || value > range[1]) {
          issues.add(ToolInputValidationIssue(
            field: field,
            message: 'Value $value outside range [${range[0]}, ${range[1]}]',
            severity: ToolInputValidationSeverity.error,
          ));
          sanitized.remove(field);
          wasModified = true;
        }
      }
    }

    // Gate 4: Injection detection
    final injectionPatterns = [
      RegExp(r'<script'),
      RegExp(r'javascript:'),
      RegExp(r'on\w+\s*='),
      RegExp(r'\$\{.*\}'),
      RegExp(r'\.\./'),
      RegExp(r';\s*(drop|delete|insert|update|alter)\s',
          caseSensitive: false),
    ];

    for (final entry in rawParams.entries) {
      if (entry.value is String) {
        final value = entry.value as String;
        for (final pattern in injectionPatterns) {
          if (pattern.hasMatch(value)) {
            issues.add(ToolInputValidationIssue(
              field: 'injection',
              message: 'Potential injection in "${entry.key}"',
              severity: ToolInputValidationSeverity.error,
            ));
            sanitized[entry.key] = value
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .replaceAll(RegExp(r'[;\'\"\\]'), '');
            wasModified = true;
            break;
          }
        }
      }
    }

    final isValid = issues
        .where((i) => i.severity == ToolInputValidationSeverity.error)
        .isEmpty;

    return InputValidationResult(
      isValid: isValid,
      errors: issues,
      sanitizedParams: Map.unmodifiable(sanitized),
      wasSanitized: wasModified,
    );
  }

  /// Determine the type string of a value.
  String _typeOf(dynamic value) {
    if (value is String) return 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List) return 'List';
    if (value is Map) return 'Map';
    return 'dynamic';
  }

  /// Convert an InputValidationResult to a ToolInput.
  /// Used by the engine to bridge validator output to tool input.
  ToolInput toToolInput(
    String toolId,
    Map<String, dynamic> rawParams,
    InputValidationResult result,
  ) {
    if (result.isValid) {
      return ToolInput.valid(
        toolId: toolId,
        params: result.sanitizedParams,
        wasSanitized: result.wasSanitized,
      );
    }
    // Build issues list for invalid input
    if (result.errors.length == 1) {
      return ToolInput.invalid(
        toolId: toolId,
        rawParams: rawParams,
        field: result.errors.first.field,
        message: result.errors.first.message,
      );
    }
    return ToolInput.withIssues(
      toolId: toolId,
      rawParams: rawParams,
      issues: result.errors,
      sanitizedParams: result.sanitizedParams,
      wasSanitized: result.wasSanitized,
    );
  }
}
