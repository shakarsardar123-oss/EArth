/// Structural tests for SensitiveDataRedactor domain contract.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/services/sensitive_data_redactor.dart';

void main() {
  group('RedactionResult', () {
    test('wasOverRedacted is true when more data was redacted than necessary', () {
      final result = RedactionResult(
        originalText: 'My email is test@example.com and name is John',
        redactedText: '[REDACTED] [REDACTED]',
        appliedRules: ['email_rule', 'name_rule'],
        wasOverRedacted: true,
      );
      expect(result.wasOverRedacted, isTrue);
    });

    test('wasOverRedacted is false when redaction was precise', () {
      final result = RedactionResult(
        originalText: 'My email is test@example.com',
        redactedText: 'My email is [EMAIL_REDACTED]',
        appliedRules: ['email_rule'],
        wasOverRedacted: false,
      );
      expect(result.wasOverRedacted, isFalse);
    });
  });
}
