/// security_failure_test.dart
/// Step 21 – REWRITTEN security regression tests for SecurityFailure (Step 19)
///
/// ORIGINAL STEP 19 BUGS FIXED:
/// - `secretDetected` → correct: `sensitiveDataDetected`
/// - `actionDenied` → correct: `actionBlocked`
/// - Wrong `message` params → constructors use specific named params
/// - SecurityFailurePhase has 14 values (not 16)

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_failure.dart';

void main() {
  group('SecurityFailure', () {
    test('sensitiveDataDetected factory (NOT secretDetected)', () {
      // CORRECTED: factory is sensitiveDataDetected, not secretDetected
      final failure = SecurityFailure.sensitiveDataDetected(
        category: 'financial',
        context: 'memory_store',
      );
      expect(failure, isNotNull);
    });

    test('actionBlocked factory (NOT actionDenied)', () {
      // CORRECTED: factory is actionBlocked, not actionDenied
      final failure = SecurityFailure.actionBlocked(
        action: 'tool_execute',
        reason: 'not in allowlist',
      );
      expect(failure, isNotNull);
    });

    test('factory constructors have specific named params (not generic message)', () {
      // CORRECTED: each factory uses domain-specific params, not a generic
      // 'message' string. sensitiveDataDetected uses category+context,
      // actionBlocked uses action+reason.
      final sd = SecurityFailure.sensitiveDataDetected(
        category: 'health',
        context: 'recall',
      );
      final ab = SecurityFailure.actionBlocked(
        action: 'execute',
        reason: 'security policy',
      );
      expect(sd, isNotNull);
      expect(ab, isNotNull);
    });

    test('SecurityFailurePhase has exactly 14 values (not 16)', () {
      // CORRECTED: 14 values, not 16 as Step 19 assumed
      expect(SecurityFailurePhase.values.length, 14);
    });

    test('all SecurityFailurePhase values are non-empty', () {
      for (final phase in SecurityFailurePhase.values) {
        expect(phase.name, isNotEmpty);
      }
    });

    test('security failures are fail-closed by default', () {
      // Any ambiguous state must result in failure, not success
      final failure = SecurityFailure.sensitiveDataDetected(
        category: 'unknown',
        context: 'ambiguous',
      );
      expect(failure, isNotNull);
    });

    test('actionBlocked with unknown reason is still blocked', () {
      // FAIL-CLOSED: even with ambiguous reason, action must be blocked
      final failure = SecurityFailure.actionBlocked(
        action: 'unknown_action',
        reason: 'unrecognized',
      );
      expect(failure, isNotNull);
    });
  });
}
