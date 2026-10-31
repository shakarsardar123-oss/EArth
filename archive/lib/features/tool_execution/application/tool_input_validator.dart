/// tool_input_validator.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Input validation service for tool execution.
/// Validates parameters before they reach tool implementations.
/// Performs sanitization (XSS, injection, overflow prevention).
/// FAIL CLOSED: any suspicious input is rejected.
library;

import '../domain/models/tool_input.dart';

/// Validation error for a specific field.
class ValidationError {
  final String field;
  final String message;
  final ValidationErrorSeverity severity;

  const ValidationError({
    required this.field,
    required this.message,
    this.severity = ValidationErrorSeverity.error,
  });

  @override
  String toString() => 'ValidationError($field: $message)';
}

/// Severity of a validation error.
enum ValidationErrorSeverity {
  warning,
  error,
  critical,
  ;

  bool get isBlocking => this != warning;
}

/// Result of input validation.
class InputValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  final Map<String, dynamic> sanitizedParams;
  final bool wasSanitized;

  const InputValidationResult({
    required this.isValid,
    required this.errors,
    required this.sanitizedParams,
    this.wasSanitized = false,
  });

  List<ValidationError> get blockingErrors =>
      errors.where((e) => e.severity.isBlocking).toList();
}

/// Input validator for tool parameters.
///
/// Validates and sanitizes input before tool execution.
/// All checks are FAIL CLOSED — any doubt results in rejection.
class ToolInputValidator {
  /// Maximum string length for any parameter value.
  static const int maxStringLength = 10000;

  /// Maximum depth for nested maps.
  static const int maxNestingDepth = 10;

  /// Maximum number of keys in a map.
  static const int maxMapKeys = 100;

  /// Maximum size of a list parameter.
  static const int maxListSize = 1000;

  /// Dangerous patterns that indicate injection attempts.
  static const List<RegExp> _dangerousPatterns = [
    RegExp(r'<script[^>]*>'),           // XSS
    RegExp(r'javascript:'),             // JS URI
    RegExp(r'on\w+\s*='),              // Event handlers
    RegExp(r'eval\s*\('),              // eval injection
    RegExp(r'document\.'),             // DOM access
    RegExp(r'window\.'),               // Window access
    RegExp(r'\$\{.*\}'),               // Template injection
    RegExp(r'(\.\.\/){3,}'),            // Path traversal
    RegExp(r';\s*(DROP|DELETE|INSERT|UPDATE|ALTER)\s', caseSensitive: false), // SQL
  ];

  /// Validate tool parameters.
  ///
  /// Returns [InputValidationResult] with sanitized params and any errors.
  InputValidationResult validate(
    String toolId,
    Map<String, dynamic> params,
  ) {
    final errors = <ValidationError>[];
    var sanitized = Map<String, dynamic>.from(params);
    var wasSanitized = false;

    // ─── Structural validation ────────────────────────────────────────
    _validateStructure('', sanitized, errors, 0);

    // ─── Injection pattern check ─────────────────────────────────────
    final injectionErrors = _checkInjectionPatterns(toolId, sanitized);
    if (injectionErrors.isNotEmpty) {
      errors.addAll(injectionErrors);
    }

    // ─── Sanitization ────────────────────────────────────────────────
    final sanitizeResult = _sanitize(toolId, sanitized);
    sanitized = sanitizeResult.params;
    if (sanitizeResult.wasModified) wasSanitized = true;

    // ─── Determine validity ───────────────────────────────────────────
    final hasBlocking = errors.any((e) => e.severity.isBlocking);

    return InputValidationResult(
      isValid: !hasBlocking,
      errors: errors,
      sanitizedParams: sanitized,
      wasSanitized: wasSanitized,
    );
  }

  /// Create a ToolInput from raw parameters.
  ToolInput createToolInput(
    String toolId,
    Map<String, dynamic> params, {
    String source = 'user',
  }) {
    final result = validate(toolId, params);

    final issues = result.errors
        .map((e) => ToolInputValidationIssue(
              field: e.field,
              message: e.message,
              severity: e.severity == ValidationErrorSeverity.warning
                  ? ToolInputValidationSeverity.warning
                  : ToolInputValidationSeverity.error,
            ))
        .toList();

    if (result.isValid) {
      return ToolInput.valid(
        toolId: toolId,
        params: result.sanitizedParams,
        wasSanitized: result.wasSanitized,
        source: source,
      );
    } else if (issues.length == 1) {
      return ToolInput.invalid(
        toolId: toolId,
        rawParams: params,
        field: issues.first.field,
        message: issues.first.message,
        source: source,
      );
    } else {
      return ToolInput.withIssues(
        toolId: toolId,
        rawParams: params,
        issues: issues,
        source: source,
      );
    }
  }

  // ─── Internal ───────────────────────────────────────────────────────

  void _validateStructure(
    String prefix,
    dynamic value,
    List<ValidationError> errors,
    int depth,
  ) {
    if (depth > maxNestingDepth) {
      errors.add(ValidationError(
        field: prefix.isEmpty ? '(root)' : prefix,
        message: 'Nesting depth exceeds maximum of $maxNestingDepth',
        severity: ValidationErrorSeverity.critical,
      ));
      return; // Don't recurse further
    }

    if (value is Map) {
      if (value.length > maxMapKeys) {
        errors.add(ValidationError(
          field: prefix.isEmpty ? '(root)' : prefix,
          message: 'Map has ${value.length} keys, maximum is $maxMapKeys',
          severity: ValidationErrorSeverity.error,
        ));
      }
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          errors.add(ValidationError(
            field: '${prefix}.$key',
            message: 'Map key must be String, got ${key.runtimeType}',
            severity: ValidationErrorSeverity.error,
          ));
          continue;
        }
        _validateStructure(
          prefix.isEmpty ? key : '$prefix.$key',
          entry.value,
          errors,
          depth + 1,
        );
      }
    } else if (value is List) {
      if (value.length > maxListSize) {
        errors.add(ValidationError(
          field: prefix.isEmpty ? '(root)' : prefix,
          message: 'List has ${value.length} items, maximum is $maxListSize',
          severity: ValidationErrorSeverity.error,
        ));
      }
      for (var i = 0; i < value.length && i < maxListSize; i++) {
        _validateStructure('$prefix[$i]', value[i], errors, depth + 1);
      }
    } else if (value is String) {
      if (value.length > maxStringLength) {
        errors.add(ValidationError(
          field: prefix.isEmpty ? '(root)' : prefix,
          message:
              'String length ${value.length} exceeds maximum $maxStringLength',
          severity: ValidationErrorSeverity.warning,
        ));
      }
    }
    // Numbers, bools, null are safe
  }

  List<ValidationError> _checkInjectionPatterns(
    String toolId,
    Map<String, dynamic> params,
  ) {
    final errors = <ValidationError>[];
    _walkStrings(params, '', (path, value) {
      for (final pattern in _dangerousPatterns) {
        if (pattern.hasMatch(value)) {
          errors.add(ValidationError(
            field: path,
            message: 'Potentially dangerous pattern detected',
            severity: ValidationErrorSeverity.critical,
          ));
          break; // One match per field is enough
        }
      }
    });
    return errors;
  }

  _SanitizeResult _sanitize(String toolId, Map<String, dynamic> params) {
    var modified = false;
    final result = _sanitizeMap(params, '', (path, original, sanitized) {
      if (original != sanitized) modified = true;
    });
    return _SanitizeResult(params: result, wasModified: modified);
  }

  Map<String, dynamic> _sanitizeMap(
    Map<String, dynamic> map,
    String prefix,
    void Function(String, String, String) onModified,
  ) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key;
      final path = prefix.isEmpty ? key : '$prefix.$key';
      result[key] = _sanitizeValue(entry.value, path, onModified);
    }
    return result;
  }

  dynamic _sanitizeValue(
    dynamic value,
    String path,
    void Function(String, String, String) onModified,
  ) {
    if (value is String) {
      final sanitized = _sanitizeString(value);
      if (sanitized != value) onModified(path, value, sanitized);
      return sanitized;
    } else if (value is Map<String, dynamic>) {
      return _sanitizeMap(value, path, onModified);
    } else if (value is List) {
      return value
          .map((e) => _sanitizeValue(e, path, onModified))
          .toList();
    }
    return value;
  }

  String _sanitizeString(String value) {
    // Trim whitespace
    var result = value.trim();
    // Strip null bytes
    result = result.replaceAll(RegExp(r'\x00'), '');
    // Normalize unicode
    result = result.replaceAll(RegExp(r'[�]'), '');
    // Truncate if over max length
    if (result.length > maxStringLength) {
      result = result.substring(0, maxStringLength);
    }
    return result;
  }

  void _walkStrings(
    dynamic value,
    String path,
    void Function(String, String) visitor,
  ) {
    if (value is String) {
      visitor(path, value);
    } else if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final childPath = path.isEmpty ? key : '$path.$key';
        _walkStrings(entry.value, childPath, visitor);
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        _walkStrings(value[i], '$path[$i]', visitor);
      }
    }
  }
}

class _SanitizeResult {
  final Map<String, dynamic> params;
  final bool wasModified;
  const _SanitizeResult({required this.params, required this.wasModified});
}
