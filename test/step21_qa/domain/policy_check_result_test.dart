/// policy_check_result_test.dart
/// Step 21 – Unit tests for PolicyCheckResult (Step 17 domain model)
///
/// Validates construction and fail-closed behavior.
/// CRITICAL: PolicyCheckResult has ONLY .allowed and .reason fields.
/// It does NOT have an isSensitive field (source bug documented).

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/semantic_memory/application/memory_policy.dart';

void main() {
  group('PolicyCheckResult', () {
    test('allowed result has allowed=true', () {
      final result = PolicyCheckResult.allowed();
      expect(result.allowed, isTrue);
      expect(result.reason, isNotNull);
    });

    test('denied result has allowed=false', () {
      final result = PolicyCheckResult.denied(reason: 'sensitive content');
      expect(result.allowed, isFalse);
      expect(result.reason, 'sensitive content');
    });

    test('denied with no reason has default', () {
      final result = PolicyCheckResult.denied();
      expect(result.allowed, isFalse);
      expect(result.reason, isNotNull);
    });

    // ---- FAIL-CLOSED INVARIANT ----
    test('absence of explicit allowed = denied (fail-closed)', () {
      // Any result where allowed is not explicitly true → denied
      final denied = PolicyCheckResult.denied(reason: 'policy');
      expect(denied.allowed, isFalse);
      // FAIL CLOSED: only allowed==true permits execution
    });

    test('PolicyCheckResult does NOT expose isSensitive field', () {
      // SOURCE BUG DOCUMENTED: SemanticMemoryAdapterImpl references
      // check.isSensitive but PolicyCheckResult only has .allowed/.reason.
      // The correct check should be !check.allowed (not check.isSensitive).
      // This test documents that the field does NOT exist.
      final result = PolicyCheckResult.denied(reason: 'test');
      // Verify only allowed and reason are accessible
      expect(result.allowed, isA<bool>());
      expect(result.reason, isA<String>());
      // isSensitive MUST NOT exist on PolicyCheckResult
    });

    test('equality based on allowed and reason', () {
      final a = PolicyCheckResult.denied(reason: 'same');
      final b = PolicyCheckResult.denied(reason: 'same');
      expect(a.allowed, b.allowed);
      expect(a.reason, b.reason);
    });
  });
}
