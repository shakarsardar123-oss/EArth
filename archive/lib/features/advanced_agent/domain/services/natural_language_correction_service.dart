/// natural_language_correction_service.dart
/// AURA Assistant – Step 25: Capability 7 — Natural Language Correction
///
/// Abstract service interface for NL-based correction of inputs/outputs.
library;

import '../models/natural_language_correction.dart';

/// Service responsible for applying natural language corrections
/// to user inputs, agent outputs, step descriptions, and tool parameters.
abstract class NaturalLanguageCorrectionService {
  /// Apply correction to a given text.
  NaturalLanguageCorrection correct({
    required String correctionId,
    required String originalText,
    String? correctionHint,
    CorrectionType type = CorrectionType.userInput,
    String? stepId,
    String? planId,
    String locale = 'ku',
  });

  /// Correct a step description within a plan.
  NaturalLanguageCorrection correctStepDescription({
    required String correctionId,
    required String originalText,
    required String stepId,
    required String planId,
    String? correctionHint,
    String locale = 'ku',
  });

  /// Whether the correction should be auto-applied or require
  /// human confirmation.
  bool shouldAutoApply(NaturalLanguageCorrection correction);
}
