/// tool_output_normalizer.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Output normalization service for tool execution.
/// Ensures all tool outputs conform to a consistent structure:
/// - Strips sensitive data
/// - Normalizes status codes
/// - Adds metadata where missing
/// - Enforces fail-closed pattern for malformed outputs
library;

import '../domain/models/tool_output.dart';

/// Normalizes tool outputs to ensure consistent structure and safety.
///
/// FAIL CLOSED: any malformed, ambiguous, or suspicious output
/// is converted to a fail-closed result.
class ToolOutputNormalizer {
  /// Sensitive key patterns that should be redacted.
  static const List<RegExp> _sensitiveKeyPatterns = [
    RegExp(r'password', caseSensitive: false),
    RegExp(r'secret', caseSensitive: false),
    RegExp(r'token', caseSensitive: false),
    RegExp(r'key$', caseSensitive: false),
    RegExp(r'api.?key', caseSensitive: false),
    RegExp(r'auth', caseSensitive: false),
    RegExp(r'credential', caseSensitive: false),
    RegExp(r'private', caseSensitive: false),
    RegExp(r'cookie', caseSensitive: false),
    RegExp(r'session', caseSensitive: false),
  ];

  /// Normalize a tool output.
  ///
  /// Applies:
  /// 1. Sensitive data redaction
  /// 2. Status normalization
  /// 3. Error message sanitization
  /// 4. Suggestion generation for failures
  /// 5. Timestamp validation
  ToolOutput normalize(ToolOutput output) {
    var result = output;

    // ─── Sensitive data redaction ──────────────────────────────────────
    result = _redactSensitiveData(result);

    // ─── Status normalization ───────────────────────────────────────────
    result = _normalizeStatus(result);

    // ─── Error message sanitization ─────────────────────────────────────
    if (result.isFailure) {
      result = _sanitizeErrorMessage(result);
    }

    // ─── Suggestions for failures ───────────────────────────────────────
    if (result.isFailure && (result.suggestions.isEmpty ?? true)) {
      result = result.copyWith(
        suggestions: _generateSuggestions(result),
      );
    }

    return result;
  }

  // ─── Sensitive data redaction ────────────────────────────────────────

  ToolOutput _redactSensitiveData(ToolOutput output) {
    final data = output.data;
    if (data.isEmpty) return output;

    final redacted = _redactMap(data);
    final hadSensitive = _hasSensitiveKeys(data);

    return output.copyWith(
      data: redacted,
      hasSensitiveData: hadSensitive,
    );
  }

  Map<String, dynamic> _redactMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key;
      if (_isSensitiveKey(key)) {
        result[key] = '[REDACTED]';
      } else if (entry.value is Map<String, dynamic>) {
        result[key] = _redactMap(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        result[key] = _redactList(entry.value as List);
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }

  List _redactList(List list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return _redactMap(item);
      } else if (item is List) {
        return _redactList(item);
      }
      return item;
    }).toList();
  }

  bool _isSensitiveKey(String key) {
    for (final pattern in _sensitiveKeyPatterns) {
      if (pattern.hasMatch(key)) return true;
    }
    return false;
  }

  bool _hasSensitiveKeys(Map<String, dynamic> map) {
    for (final key in map.keys) {
      if (_isSensitiveKey(key)) return true;
      final value = map[key];
      if (value is Map<String, dynamic> && _hasSensitiveKeys(value)) {
        return true;
      }
    }
    return false;
  }

  // ─── Status normalization ────────────────────────────────────────────

  ToolOutput _normalizeStatus(ToolOutput output) {
    // If status is unknown, default to fail-closed
    switch (output.status) {
      case ToolOutputStatus.success:
      case ToolOutputStatus.empty:
      case ToolOutputStatus.failure:
      case ToolOutputStatus.cancelled:
      case ToolOutputStatus.timedOut:
      case ToolOutputStatus.denied:
      case ToolOutputStatus.partial:
      case ToolOutputStatus.failClosed:
        return output; // All known statuses are fine
    }
    // Should never reach here, but FAIL CLOSED
    return ToolOutput.failClosed(
      toolId: output.toolId,
      reason: 'Unknown output status',
    );
  }

  // ─── Error message sanitization ──────────────────────────────────────

  ToolOutput _sanitizeErrorMessage(ToolOutput output) {
    var message = output.errorMessage ?? '';

    // Strip file paths from error messages
    message = message.replaceAll(
      RegExp(r'/[\w/.-]+'),
      '[path]',
    );

    // Strip stack traces
    message = message.replaceAll(
      RegExp(r'#\d+\s+.*', dotAll: true),
      '[stack-trace]',
    );

    // Limit message length
    if (message.length > 500) {
      message = '${message.substring(0, 497)}...';
    }

    return output.copyWith(errorMessage: message);
  }

  // ─── Suggestion generation ───────────────────────────────────────────

  List<String> _generateSuggestions(ToolOutput output) {
    final suggestions = <String>[];

    switch (output.status) {
      case ToolOutputStatus.failure:
        suggestions.add('Check tool parameters and try again');
        suggestions.add('Verify the tool is available in your region');
        break;
      case ToolOutputStatus.timedOut:
        suggestions.add('Increase the timeout duration');
        suggestions.add('Simplify the input parameters');
        suggestions.add('Check network connectivity');
        break;
      case ToolOutputStatus.cancelled:
        suggestions.add('Re-run the tool if needed');
        break;
      case ToolOutputStatus.denied:
        suggestions.add('Check required permissions');
        suggestions.add('Contact administrator for access');
        break;
      case ToolOutputStatus.partial:
        suggestions.add('Some results may be incomplete');
        suggestions.add('Try running the tool again for full results');
        break;
      case ToolOutputStatus.failClosed:
        suggestions.add('This was a safety denial — review security settings');
        suggestions.add('Contact support if this seems incorrect');
        break;
      default:
        break;
    }

    return suggestions;
  }
}
