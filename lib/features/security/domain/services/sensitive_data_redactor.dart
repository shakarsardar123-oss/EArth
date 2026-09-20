/// sensitive_data_redactor.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Domain service interface for redacting sensitive data.
/// FAIL CLOSED: if redaction fails, over-redact (replace entire content
/// with placeholder) rather than risk leaking data.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../models/redaction_rule.dart';
import '../models/security_failure.dart';

/// Result of a redaction operation.
class RedactionResult {
  /// The redacted content.
  final String redactedContent;

  /// Number of redactions applied.
  final int redactionCount;

  /// Categories of data that were redacted.
  final List<SensitiveDataCategory> redactedCategories;

  /// Whether the redaction was over-applied (FAIL CLOSED fallback).
  final bool wasOverRedacted;

  const RedactionResult({
    required this.redactedContent,
    this.redactionCount = 0,
    this.redactedCategories = const [],
    this.wasOverRedacted = false,
  });

  @override
  String toString() =>
      'RedactionResult(count: \$redactionCount, overRedacted: \$wasOverRedacted, '
      'categories: \${redactedCategories.map((c) => c.name).join(",")})';
}

/// Abstract domain service for redacting sensitive data from content.
///
/// Implementations MUST:
/// - Over-redact on ambiguity (prefer false positives over false negatives).
/// - Apply rules by priority (higher priority first).
/// - FAIL CLOSED: on redaction error, replace entire content with
///   a placeholder rather than pass through raw data.
abstract class SensitiveDataRedactor {
  /// Redact sensitive data from [content] using all active rules.
  ///
  /// Returns [RedactionResult] with the redacted content and metadata.
  /// On error, returns [SecurityFailure] with appropriate phase.
  Future<SecurityResult<RedactionResult>> redact(
    String content, {
    List<SensitiveDataCategory>? onlyCategories,
  });

  /// Redact a single value for a known category (quick helper).
  ///
  /// Useful when the category is already known (e.g., from a scan).
  String redactValue(String value, SensitiveDataCategory category);

  /// Get the list of currently active redaction rules.
  List<RedactionRule> get activeRules;

  /// Add a custom redaction rule.
  /// Returns true if added, false if duplicate or invalid.
  bool addCustomRule(RedactionRule rule);

  /// Remove a custom redaction rule by category + pattern.
  bool removeCustomRule(SensitiveDataCategory category);

  /// Get the default redaction rules.
  List<RedactionRule> get defaultRules;
}
