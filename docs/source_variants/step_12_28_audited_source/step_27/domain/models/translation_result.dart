/// Step 27 — Translation Result Model
///
/// Represents the result of a translation operation.
///
/// AUDIT FIX — Bug #6:
///   Changed `required this.requestId` to `this.requestId = ''`.
///   The requestId field was mandatory but not always available
///   at construction time (e.g., batch translations, streaming results).
///   Making it optional with a default empty string preserves
///   backward compatibility while allowing construction without requestId.

class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final String requestId;
  final DateTime? completedAt;
  final String? errorCode;
  final String? errorMessage;

  const TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.confidence = 0.0,
    this.requestId = '',
    this.completedAt,
    this.errorCode,
    this.errorMessage,
  });

  /// Whether the translation succeeded.
  bool get succeeded => errorCode == null && errorMessage == null;

  /// Whether the translation was denied (fail-closed).
  bool get wasDenied => errorCode == 'DENIED';

  factory TranslationResult.success({
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
    double confidence = 1.0,
    String requestId = '',
  }) {
    return TranslationResult(
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      confidence: confidence,
      requestId: requestId,
      completedAt: DateTime.now(),
    );
  }

  factory TranslationResult.failed({
    required String errorCode,
    String? errorMessage,
    String requestId = '',
  }) {
    return TranslationResult(
      translatedText: '',
      sourceLanguage: '',
      targetLanguage: '',
      confidence: 0.0,
      requestId: requestId,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  /// Fail-closed factory: denied by default.
  factory TranslationResult.denied({
    String reason = 'Translation denied by policy',
    String requestId = '',
  }) {
    return TranslationResult(
      translatedText: '',
      sourceLanguage: '',
      targetLanguage: '',
      confidence: 0.0,
      requestId: requestId,
      errorCode: 'DENIED',
      errorMessage: reason,
    );
  }
}
