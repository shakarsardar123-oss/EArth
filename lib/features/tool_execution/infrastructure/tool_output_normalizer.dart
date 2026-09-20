/// tool_output_normalizer.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Output normalizer — strips sensitive data, enforces consistency.
/// Uses ToolOutput.copyWith with containsSensitiveData (not hasSensitiveData).
/// Uses suggestions.isEmpty (not suggestions?.isEmpty — it's non-nullable).
///
/// FAIL CLOSED: any detection of sensitive data triggers redaction.
library;

import '../domain/models/tool_output.dart';

class ToolOutputNormalizer {
  /// Sensitive key patterns to detect in output data.
  static const _sensitiveKeyPatterns = [
    'password',
    'token',
    'secret',
    'key',
    'credential',
    'auth',
    'session',
    'cookie',
    'api_key',
    'access_token',
    'refresh_token',
    'private',
    'ssn',
    'social_security',
    'credit_card',
    'card_number',
  ];

  /// Normalize a tool output for safe presentation.
  ///
  /// 1. Detect and redact sensitive data
  /// 2. Add suggestions if the output is empty or failed
  /// 3. Enforce locale-appropriate formatting
  ToolOutput normalize(ToolOutput output, {String locale = 'ku'}) {
    var result = output;

    // Step 1: Detect sensitive data
    final sensitiveData = _detectSensitiveData(output.data);
    if (sensitiveData.found) {
      result = result.copyWith(
        containsSensitiveData: true,
        sensitiveCategories: sensitiveData.categories,
        data: _redactSensitiveData(output.data, sensitiveData.keys),
      );
    }

    // Step 2: Add suggestions for failed/empty outputs
    if (result.status.isFailure && result.suggestions.isEmpty) {
      result = result.copyWith(
        suggestions: _generateFailureSuggestions(result),
      );
    }

    // Step 3: Locale formatting (RTL for Kurdish Sorani)
    if (locale == 'ku') {
      result = _applyRtlFormatting(result);
    }

    return result;
  }

  /// Detect sensitive data in a map.
  _SensitiveDataResult _detectSensitiveData(
      Map<String, dynamic> data) {
    final foundKeys = <String>[];
    final categories = <SensitiveDataCategory>[];

    for (final entry in data.entries) {
      final keyLower = entry.key.toLowerCase();
      for (final pattern in _sensitiveKeyPatterns) {
        if (keyLower.contains(pattern)) {
          foundKeys.add(entry.key);
          categories.add(_categorizeSensitiveKey(pattern));
          break;
        }
      }
    }

    return _SensitiveDataResult(
      found: foundKeys.isNotEmpty,
      keys: foundKeys,
      categories: List.unmodifiable(categories),
    );
  }

  /// Categorize a sensitive key pattern.
  SensitiveDataCategory _categorizeSensitiveKey(String pattern) {
    if (pattern.contains('password') || pattern.contains('credential') ||
        pattern.contains('token') || pattern.contains('key') ||
        pattern.contains('auth') || pattern.contains('session')) {
      return SensitiveDataCategory.credentials;
    }
    if (pattern.contains('ssn') || pattern.contains('social') ||
        pattern.contains('card')) {
      return SensitiveDataCategory.personalInfo;
    }
    if (pattern.contains('cookie')) {
      return SensitiveDataCategory.credentials;
    }
    return SensitiveDataCategory.personalInfo;
  }

  /// Redact sensitive data values in a map.
  Map<String, dynamic> _redactSensitiveData(
    Map<String, dynamic> data,
    List<String> sensitiveKeys,
  ) {
    final result = Map<String, dynamic>.from(data);
    for (final key in sensitiveKeys) {
      if (result.containsKey(key)) {
        result[key] = '[REDACTED]';
      }
    }
    return Map.unmodifiable(result);
  }

  /// Generate suggestions for failed outputs.
  List<String> _generateFailureSuggestions(ToolOutput output) {
    switch (output.status) {
      case ToolOutputStatus.failure:
        return ['Check input parameters and retry'];
      case ToolOutputStatus.cancelled:
        return ['Retry the operation if still needed'];
      case ToolOutputStatus.timedOut:
        return ['Increase timeout or simplify the request'];
      case ToolOutputStatus.denied:
        return ['Check permissions and try again'];
      case ToolOutputStatus.failClosed:
        return ['Contact support — this may be a system issue'];
      default:
        return [];
    }
  }

  /// Apply RTL formatting for Kurdish Sorani.
  ToolOutput _applyRtlFormatting(ToolOutput output) {
    // Kurdish Sorani is RTL — ensure messages are appropriately
    // formatted. This is primarily a marker for l10n integration;
    // actual string translations come from l10n bundles.
    return output;
  }
}

/// Internal result type for sensitive data detection.
class _SensitiveDataResult {
  final bool found;
  final List<String> keys;
  final List<SensitiveDataCategory> categories;

  const _SensitiveDataResult({
    required this.found,
    this.keys = const [],
    this.categories = const [],
  });
}
