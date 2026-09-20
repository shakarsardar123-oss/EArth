/// retry_policy_test.dart
/// AURA Assistant – Step 18: Agent Replanning, Recovery & Retry
///
/// Structural tests for RetryPolicy model.
/// No Flutter/Dart SDK — structural/mock tests only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/retry_policy.dart';
import 'package:aura_assistant/features/agent_recovery/domain/models/recovery_failure_phase.dart';

void main() {
  group('RetryPolicy', () {
    test('default constructor has correct defaults', () {
      const policy = RetryPolicy();
      expect(policy.maxRetriesPerStep, 3);
      expect(policy.maxTotalRetries, 10);
      expect(policy.backoffConfig, isNotNull);
    });

    test('copyWith preserves existing values', () {
      const policy = RetryPolicy();
      final copied = policy.copyWith(maxRetriesPerStep: 5);
      expect(copied.maxRetriesPerStep, 5);
      expect(copied.maxTotalRetries, 10);
    });

    test('copyWith can update all fields', () {
      const policy = RetryPolicy();
      final copied = policy.copyWith(
        maxRetriesPerStep: 7,
        maxTotalRetries: 20,
      );
      expect(copied.maxRetriesPerStep, 7);
      expect(copied.maxTotalRetries, 20);
    });

    test('isRetryable returns true for retryable phases', () {
      const policy = RetryPolicy();
      // screenParsing, llmCall, toolExecution, networkRequest are retryable
      expect(
          policy.isRetryable(RecoveryFailurePhase.screenParsing), true);
      expect(policy.isRetryable(RecoveryFailurePhase.llmCall), true);
      expect(
          policy.isRetryable(RecoveryFailurePhase.toolExecution), true);
      expect(
          policy.isRetryable(RecoveryFailurePhase.networkRequest), true);
    });

    test('isRetryable returns false for non-retryable phases', () {
      const policy = RetryPolicy();
      // userCancellation and policyViolation are not retryable
      expect(
          policy.isRetryable(RecoveryFailurePhase.userCancellation), false);
      expect(
          policy.isRetryable(RecoveryFailurePhase.policyViolation), false);
    });

    test('isStepRetryExhausted checks per-step limit', () {
      const policy = RetryPolicy();
      expect(policy.isStepRetryExhausted(3), true);
      expect(policy.isStepRetryExhausted(2), false);
      expect(policy.isStepRetryExhausted(0), false);
    });

    test('isTotalRetryExhausted checks total limit', () {
      const policy = RetryPolicy();
      expect(policy.isTotalRetryExhausted(10), true);
      expect(policy.isTotalRetryExhausted(9), false);
      expect(policy.isTotalRetryExhausted(0), false);
    });

    test('equality works for identical policies', () {
      const a = RetryPolicy();
      const b = RetryPolicy();
      expect(a, equals(b));
    });

    test('hashCode consistency', () {
      const a = RetryPolicy();
      const b = RetryPolicy();
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ExponentialBackoffConfig exists with defaults', () {
      const config = ExponentialBackoffConfig();
      expect(config.initialDelayMs, isNotNull);
      expect(config.maxDelayMs, isNotNull);
      expect(config.multiplier, isNotNull);
    });
  });
}
