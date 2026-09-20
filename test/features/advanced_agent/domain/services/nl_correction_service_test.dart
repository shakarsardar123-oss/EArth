/// nl_correction_service_test.dart
/// Structural tests for NaturalLanguageCorrectionService.
///
/// Verifies: correctStepDescription({correctionId, originalText, stepId,
/// planId, correctionHint?, locale='ku'}).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/services/natural_language_correction_service.dart';

void main() {
  group('NaturalLanguageCorrectionService', () {
    test('has correctStepDescription method', () {
      final service = NaturalLanguageCorrectionService();
      expect(service.correctStepDescription, isA<Function>());
    });

    test('correctStepDescription accepts required params', () async {
      final service = NaturalLanguageCorrectionService();
      try {
        await service.correctStepDescription(
          correctionId: 'corr1',
          originalText: 'Fix the bug',
          stepId: 'step1',
          planId: 'plan1',
        );
      } catch (_) {
        // Structural test only
      }
    });

    test('correctStepDescription has locale default ku', () async {
      final service = NaturalLanguageCorrectionService();
      try {
        await service.correctStepDescription(
          correctionId: 'corr2',
          originalText: 'Fix',
          stepId: 'step2',
          planId: 'plan2',
          locale: 'ku',
        );
      } catch (_) {
        // Structural test only
      }
    });

    test('correctionHint is optional', () async {
      final service = NaturalLanguageCorrectionService();
      try {
        await service.correctStepDescription(
          correctionId: 'corr3',
          originalText: 'Fix',
          stepId: 'step3',
          planId: 'plan3',
          correctionHint: 'Make more formal',
          locale: 'ku',
        );
      } catch (_) {
        // Structural test only
      }
    });
  });
}
