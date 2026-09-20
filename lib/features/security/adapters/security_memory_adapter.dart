/// security_memory_adapter.dart
/// AURA Assistant – Step 19: Security & Privacy Hardening
///
/// Adapter bridging Security feature with Step 17 MemoryPolicy.
/// Ensures memory operations comply with privacy policies and
/// sensitive data never enters persistent memory unredacted.
///
/// FAIL CLOSED: if memory policy check fails or is inconclusive,
/// the memory operation is denied.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/models/security_failure.dart';
import '../domain/models/security_verdict.dart';

/// Memory operation types that need security checks.
enum SecurityMemoryOperation {
  /// Storing (remembering) data.
  store,

  /// Recalling (reading) stored data.
  recall,

  /// Searching through stored data.
  search,

  /// Forgetting (deleting) stored data.
  forget,

  /// Updating stored data.
  update,

  /// Unknown — FAIL CLOSED: treated as store (most restrictive).
  unknown,
}

/// Result of a memory privacy check.
class MemoryPrivacyResult {
  /// Whether the memory operation is allowed.
  final bool isAllowed;

  /// The memory operation that was checked.
  final SecurityMemoryOperation operation;

  /// Whether the content was redacted before memory storage.
  final bool wasContentRedacted;

  /// The redacted version of the content (safe for memory storage).
  final String? redactedContent;

  /// Reason for denial (if denied).
  final String? denialReason;

  /// Whether this is a fail-closed denial.
  final bool isFailClosedDenial;

  /// The sensitivity categories detected in the content.
  final List<String> detectedSensitivityFlags;

  const MemoryPrivacyResult({
    required this.isAllowed,
    required this.operation,
    this.wasContentRedacted = false,
    this.redactedContent,
    this.denialReason,
    this.isFailClosedDenial = false,
    this.detectedSensitivityFlags = const [],
  });

  /// FAIL CLOSED: denied with fail-closed flag.
  factory MemoryPrivacyResult.failClosedDenial({
    required SecurityMemoryOperation operation,
    String? reason,
  }) =>
      MemoryPrivacyResult(
        isAllowed: false,
        operation: operation,
        denialReason: reason ?? 'Memory operation denied — fail closed',
        isFailClosedDenial: true,
      );

  /// Convert to a SecurityVerdict.
  SecurityVerdict get asVerdict {
    if (isAllowed) {
      return SecurityVerdict.allowed(
        action: operation.name,
        reason: wasContentRedacted
            ? 'Content redacted before memory operation'
            : 'Content passed memory privacy check',
      );
    }
    return SecurityVerdict.denied(
      action: operation.name,
      reason: denialReason ?? 'Memory operation denied',
      category: SensitiveDataCategory.nationalId,
    );
  }
}

/// Abstract adapter for integrating security with memory system.
///
/// All memory operations must pass through this adapter to ensure:
/// 1. MemoryPolicy.isSensitive is checked before any store operation
/// 2. Sensitive content is redacted before entering memory
/// 3. Fail-closed: if policy check is inconclusive, deny the operation
abstract class SecurityMemoryAdapter {
  /// Check whether a memory operation is allowed for given content.
  Future<SecurityResult<MemoryPrivacyResult>> checkMemoryOperation(
    SecurityMemoryOperation operation,
    String content, {
    Map<String, dynamic> context = const {},
  });

  /// Prepare content for safe memory storage.
  /// This redacts any sensitive data before storage.
  Future<SecurityResult<String>> prepareContentForMemory(
    String content, {
    Map<String, dynamic> context = const {},
  });

  /// Check if content is marked as sensitive by memory policy.
  Future<SecurityResult<bool>> isContentSensitive(
    String content, {
    Map<String, dynamic> context = const {},
  });

  /// Get the list of sensitivity flags for content.
  Future<SecurityResult<List<String>>> getContentSensitivityFlags(
    String content, {
    Map<String, dynamic> context = const {},
  });
}
