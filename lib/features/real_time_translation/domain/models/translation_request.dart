/// translation_request.dart
/// AURA Assistant – Step 27: Real-Time Translation Pipeline
///
/// Domain model for a translation request.
/// FAIL-CLOSED: unknown language → denied, empty text → denied,
///              unavailable → denied.
/// Kurdish Sorani RTL-first: default source='ckb_IQ', locale='ku'.
library;

import 'package:meta/meta.dart';

/// Supported translation language codes.
enum TranslationLanguage {
  kurdishSorani('ckb_IQ'),
  english('en_US'),
  arabic('ar_IQ'),
  persian('fa_IR'),
  turkish('tr_TR'),
  unknown('unknown');

  final String code;
  const TranslationLanguage(this.code);

  static TranslationLanguage fromCode(String code) =>
      TranslationLanguage.values.firstWhere(
        (e) => e.code == code,
        orElse: () => TranslationLanguage.unknown,
      );

  /// FAIL-CLOSED: unknown languages are never translatable.
  bool get isTranslatable => this != unknown;
}

/// Translation direction.
enum TranslationDirection {
  toKurdish,
  fromKurdish,
  unknown,
  ;

  static TranslationDirection fromName(String name) =>
      TranslationDirection.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TranslationDirection.unknown,
      );

  /// FAIL-CLOSED: unknown direction is not usable.
  bool get isUsable => this != unknown;
}

/// Immutable translation request.
@immutable
class TranslationRequest {
  /// Unique request identifier.
  final String requestId;

  /// Source text to translate.
  final String sourceText;

  /// Source language code.
  final TranslationLanguage sourceLanguage;

  /// Target language code.
  final TranslationLanguage targetLanguage;

  /// Translation direction.
  final TranslationDirection direction;

  /// Whether this is a real-time (streaming) request.
  final bool isRealTime;

  /// Confidence threshold for accepting translation (0.0-1.0).
  final double confidenceThreshold;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Timestamp of the request.
  final DateTime createdAt;

  const TranslationRequest({
    required this.requestId,
    required this.sourceText,
    this.sourceLanguage = TranslationLanguage.unknown,
    this.targetLanguage = TranslationLanguage.kurdishSorani,
    this.direction = TranslationDirection.unknown,
    this.isRealTime = false,
    this.confidenceThreshold = 0.7,
    this.locale = 'ku',
    required this.createdAt,
  });

  /// FAIL-CLOSED: factory for invalid/unknown requests.
  factory TranslationRequest.invalid({
    required String requestId,
    String reason = 'Unknown translation request',
  }) =>
      TranslationRequest(
        requestId: requestId,
        sourceText: '',
        sourceLanguage: TranslationLanguage.unknown,
        direction: TranslationDirection.unknown,
        createdAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: empty source text is not translatable.
  bool get isTranslatable =>
      sourceText.isNotEmpty &&
      sourceLanguage.isTranslatable &&
      targetLanguage.isTranslatable &&
      direction.isUsable;

  @override
  String toString() =>
      'TranslationRequest(id: $requestId, $sourceLanguage → $targetLanguage, '
      'realtime: $isRealTime)';
}
