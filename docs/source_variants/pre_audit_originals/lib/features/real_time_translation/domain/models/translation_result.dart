/// translation_result.dart
/// AURA Assistant – Step 27: Real-Time Translation Pipeline
///
/// Domain model for the result of a translation.
/// FAIL-CLOSED: low confidence → denied/ask, error → denied,
///              unknown → denied.
library;

import 'package:meta/meta.dart';
import 'translation_request.dart';

/// Status of a translation result.
enum TranslationStatus {
  success,
  lowConfidence,
  failed,
  denied,
  timedOut,
  unavailable,
  unknown,
  ;

  static TranslationStatus fromName(String name) =>
      TranslationStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TranslationStatus.unknown,
      );

  /// FAIL-CLOSED: only success is usable.
  bool get isSuccess => this == success;

  /// Low confidence — FAIL-CLOSED: treat as denied/ask.
  bool get isLowConfidence => this == lowConfidence;

  /// Whether the result should be blocked.
  bool get isBlocked =>
      this == failed || this == denied || this == timedOut ||
      this == unavailable || this == unknown;
}

/// Immutable translation result.
@immutable
class TranslationResult {
  /// The request that produced this result.
  final String requestId;

  /// Status of the translation.
  final TranslationStatus status;

  /// Translated text (empty if failed/denied).
  final String translatedText;

  /// Confidence score (0.0-1.0).
  final double confidence;

  /// Detected source language (if different from request).
  final TranslationLanguage detectedLanguage;

  /// Whether the translation is RTL.
  final bool isRtl;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Error message (only for failure/denied/unknown status).
  final String? errorMessage;

  /// Timestamp of the result.
  final DateTime completedAt;

  const TranslationResult({
    required this.requestId,
    this.status = TranslationStatus.unknown,
    this.translatedText = '',
    this.confidence = 0.0,
    this.detectedLanguage = TranslationLanguage.unknown,
    this.isRtl = true,
    this.locale = 'ku',
    this.errorMessage,
    required this.completedAt,
  });

  /// FAIL-CLOSED: factory for denied translation.
  factory TranslationResult.denied({
    required String requestId,
    String? reason,
  }) =>
      TranslationResult(
        requestId: requestId,
        status: TranslationStatus.denied,
        errorMessage: reason ?? 'Translation denied (fail-closed)',
        completedAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: factory for low-confidence translation.
  factory TranslationResult.lowConfidence({
    required String requestId,
    required String translatedText,
    required double confidence,
  }) =>
      TranslationResult(
        requestId: requestId,
        status: TranslationStatus.lowConfidence,
        translatedText: translatedText,
        confidence: confidence,
        isRtl: true,
        completedAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: factory for unknown/failed translation.
  factory TranslationResult.unknown({
    required String requestId,
    String? error,
  }) =>
      TranslationResult(
        requestId: requestId,
        status: TranslationStatus.unknown,
        errorMessage: error ?? 'Unknown translation failure — failing closed',
        completedAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: low confidence should be treated as denied/ask.
  bool get shouldDeny =>
      status.isBlocked || status.isLowConfidence;

  @override
  String toString() =>
      'TranslationResult(id: $requestId, status: $status, '
      'conf: $confidence, rtl: $isRtl)';
}
