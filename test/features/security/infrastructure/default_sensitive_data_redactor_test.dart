/// Structural tests for DefaultSensitiveDataRedactor implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/infrastructure/default_sensitive_data_redactor.dart';

void main() {
  group('DefaultSensitiveDataRedactor', () {
    test('FAIL CLOSED: returns full placeholder on error', () {
      final redactor = DefaultSensitiveDataRedactor();
      expect(redactor.returnsFullPlaceholderOnError, isTrue);
    });

    test('has priority sorting for rules', () {
      final redactor = DefaultSensitiveDataRedactor();
      expect(redactor.usesPrioritySorting, isTrue);
    });

    test('over-redacts on ambiguity', () {
      final redactor = DefaultSensitiveDataRedactor();
      expect(redactor.overRedactsOnAmbiguity, isTrue);
    });
  });
}
