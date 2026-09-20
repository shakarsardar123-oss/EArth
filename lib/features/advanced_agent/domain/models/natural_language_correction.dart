/// natural_language_correction.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Natural language correction request and result (capability 7).
/// Used to refine user input or agent output through NL interpretation.
library;

/// Type of correction being requested.
enum CorrectionType {
  /// Correct the user's input (e.g., typo, ambiguous phrasing).
  userInput,

  /// Correct the agent's planned output (e.g., refine plan description).
  agentOutput,

  /// Correct a step description within a plan.
  stepDescription,

  /// Correct a tool parameter value.
  toolParameter,
  ;

  /// FAIL-CLOSED: any unknown name maps to [userInput].
  static CorrectionType fromName(String name) {
    return CorrectionType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CorrectionType.userInput,
    );
  }
}

/// A request to apply natural language correction.
class NaturalLanguageCorrectionRequest {
  final String correctionId;
  final String originalText;
  final String? correctionHint;
  final CorrectionType type;
  final String? stepId;
  final String? planId;
  final String locale;

  const NaturalLanguageCorrectionRequest({
    required this.correctionId,
    required this.originalText,
    this.correctionHint,
    this.type = CorrectionType.userInput,
    this.stepId,
    this.planId,
    this.locale = 'ku',
  });

  @override
  String toString() =>
      'NLCorrectionRequest(id: $correctionId, type: $type, text: "$originalText")';
}

/// The result of applying natural language correction.
class NaturalLanguageCorrection {
  final String correctionId;
  final String originalText;
  final String correctedText;
  final CorrectionType type;
  final double confidence;
  final String rationale;
  final String locale;
  final DateTime correctedAt;

  const NaturalLanguageCorrection({
    required this.correctionId,
    required this.originalText,
    required this.correctedText,
    this.type = CorrectionType.userInput,
    this.confidence = 0.0,
    this.rationale = '',
    this.locale = 'ku',
    required this.correctedAt,
  });

  /// Whether the correction is high-confidence enough to apply automatically.
  bool get isAutoApplicable => confidence >= 0.85;

  /// Whether the corrected text differs from the original.
  bool get hasChanges => originalText != correctedText;

  /// Factory: no correction needed (original is fine).
  factory NaturalLanguageCorrection.noChange({
    required String correctionId,
    required String originalText,
    CorrectionType type = CorrectionType.userInput,
    String locale = 'ku',
  }) =>
      NaturalLanguageCorrection(
        correctionId: correctionId,
        originalText: originalText,
        correctedText: originalText,
        type: type,
        confidence: 1.0,
        rationale: 'No correction needed.',
        locale: locale,
        correctedAt: DateTime.now(),
      );

  /// Factory: correction failed (return original).
  factory NaturalLanguageCorrection.failed({
    required String correctionId,
    required String originalText,
    String rationale = 'Correction failed.',
    CorrectionType type = CorrectionType.userInput,
    String locale = 'ku',
  }) =>
      NaturalLanguageCorrection(
        correctionId: correctionId,
        originalText: originalText,
        correctedText: originalText,
        type: type,
        confidence: 0.0,
        rationale: rationale,
        locale: locale,
        correctedAt: DateTime.now(),
      );

  NaturalLanguageCorrection copyWith({
    String? correctionId,
    String? originalText,
    String? correctedText,
    CorrectionType? type,
    double? confidence,
    String? rationale,
    String? locale,
    DateTime? correctedAt,
  }) =>
      NaturalLanguageCorrection(
        correctionId: correctionId ?? this.correctionId,
        originalText: originalText ?? this.originalText,
        correctedText: correctedText ?? this.correctedText,
        type: type ?? this.type,
        confidence: confidence ?? this.confidence,
        rationale: rationale ?? this.rationale,
        locale: locale ?? this.locale,
        correctedAt: correctedAt ?? this.correctedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NaturalLanguageCorrection &&
          correctionId == other.correctionId;

  @override
  int get hashCode => correctionId.hashCode;

  @override
  String toString() =>
      'NaturalLanguageCorrection(id: $correctionId, type: $type, '
      'confidence: $confidence, changed: $hasChanges)';
}
