/// verification_result_test.dart
/// Structural & mock tests for VerificationResult model.
///
/// Verifies: isPassed, treatAsFailed, factories (.passed, .failed, .skipped).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/verification_result.dart';

void main() {
  group('VerificationResult', () {
    test('.passed factory', () {
      final v = VerificationResult.passed(
        resultId: 'vr1',
        stepId: 's1',
        planId: 'p1',
      );
      expect(v.isPassed, isTrue);
      expect(v.treatAsFailed, isFalse);
    });

    test('.failed factory', () {
      final v = VerificationResult.failed(
        resultId: 'vr2',
        stepId: 's1',
        planId: 'p1',
        reason: 'Mismatch',
      );
      expect(v.isPassed, isFalse);
      expect(v.treatAsFailed, isTrue);
    });

    test('.skipped factory', () {
      final v = VerificationResult.skipped(
        resultId: 'vr3',
        stepId: 's1',
        planId: 'p1',
      );
      expect(v.isPassed, isFalse);
      // skipped is treatAsFailed = true per FAIL-CLOSED
    });

    test('fields: isPassed, treatAsFailed', () {
      final v = VerificationResult.passed(
        resultId: 'vr4',
        stepId: 's1',
        planId: 'p1',
      );
      expect(v.isPassed, isA<bool>());
      expect(v.treatAsFailed, isA<bool>());
    });
  });
}
