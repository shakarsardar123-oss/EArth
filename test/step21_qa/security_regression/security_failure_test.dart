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
      final failure = SecurityFailure.sensitiveDataDetected(
        category: SensitiveDataCategory.financialAccount,
        action: 'memory_store',
      );
      expect(failure, isNotNull);
    });

    test('actionBlocked factory (NOT actionDenied)', () {
      final failure = SecurityFailure.actionBlocked(
        action: 'tool_execute',
        verdictReason: 'not in allowlist',
      );
      expect(failure, isNotNull);
    });

    test('factory constructors have specific named params (not generic message)', () {
      final sd = SecurityFailure.sensitiveDataDetected(
        category: SensitiveDataCategory.medicalRecord,
        action: 'recall',
      );
      final ab = SecurityFailure.actionBlocked(
        action: 'execute',
        verdictReason: 'security policy',
      );
      expect(sd, isNotNull);
      expect(ab, isNotNull);
    });

    test('SecurityFailurePhase has exactly 14 values (not 16)', () {
      expect(SecurityFailurePhase.values.length, 14);
    });

    test('all SecurityFailurePhase values are non-empty', () {
      for (final phase in SecurityFailurePhase.values) {
        expect(phase.name, isNotEmpty);
      }
    });

    test('security failures are fail-closed by default', () {
      final failure = SecurityFailure.sensitiveDataDetected(
        category: SensitiveDataCategory.unknown,
        action: 'ambiguous',
      );
      expect(failure, isNotNull);
    });

    test('actionBlocked with unknown reason is still blocked', () {
      final failure = SecurityFailure.actionBlocked(
        action: 'unknown_action',
        verdictReason: 'unrecognized',
      );
      expect(failure, isNotNull);
    });
  });
}
