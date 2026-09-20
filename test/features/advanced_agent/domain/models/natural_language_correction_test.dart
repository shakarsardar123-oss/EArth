/// natural_language_correction_test.dart
/// Structural tests for NaturalLanguageCorrection model.
///
/// Verifies: hasChanges, correctedText fields.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/natural_language_correction.dart';

void main() {
  group('NaturalLanguageCorrection', () {
    test('hasChanges is true when corrections applied', () {
      final c = NaturalLanguageCorrection(
        correctionId: 'c1',
        originalText: 'hello',
        correctedText: 'Hello',
        hasChanges: true,
      );
      expect(c.hasChanges, isTrue);
      expect(c.correctedText, 'Hello');
    });

    test('hasChanges is false when no corrections', () {
      final c = NaturalLanguageCorrection(
        correctionId: 'c2',
        originalText: 'hello',
        correctedText: 'hello',
        hasChanges: false,
      );
      expect(c.hasChanges, isFalse);
      expect(c.correctedText, 'hello');
    });

    test('fields: correctionId, originalText, correctedText, hasChanges', () {
      final c = NaturalLanguageCorrection(
        correctionId: 'c3',
        originalText: 'original',
        correctedText: 'corrected',
        hasChanges: true,
      );
      expect(c.correctionId, 'c3');
      expect(c.originalText, 'original');
      expect(c.correctedText, 'corrected');
      expect(c.hasChanges, isTrue);
    });
  });
}
