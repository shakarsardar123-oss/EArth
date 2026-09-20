/// verification_status_test.dart
/// Structural tests for VerificationStatus model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/verification_status.dart';

void main() {
  group('VerificationStatus', () {
    test('enum has expected values (passed, failed, skipped)', () {
      expect(VerificationStatus.values, containsAll([
        VerificationStatus.passed,
        VerificationStatus.failed,
        VerificationStatus.skipped,
      ]));
    });

    test('each status has a name', () {
      for (final v in VerificationStatus.values) {
        expect(v.name, isNotEmpty);
      }
    });
  });
}
