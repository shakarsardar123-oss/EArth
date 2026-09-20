/// translation_service.dart
/// AURA Assistant – Step 27: Real-Time Translation Pipeline
///
/// Abstract domain service for real-time translation.
/// FAIL-CLOSED: unknown language → denied, low confidence → denied/ask,
///              unavailable → denied, error → denied.
/// Kurdish Sorani RTL-first: locale='ku', STT='ckb_IQ', TTS='ku'.
library;

import '../models/translation_request.dart';
import '../models/translation_result.dart';

/// Abstract service for real-time translation.
abstract class TranslationService {
  /// Translate a single request.
  /// FAIL-CLOSED: unknown language → denied, low confidence → lowConfidence status.
  Future<TranslationResult> translate(TranslationRequest request);

  /// Stream translations for real-time input.
  /// FAIL-CLOSED: any error → denied result in stream.
  Stream<TranslationResult> translateStream(Stream<TranslationRequest> requests);

  /// Detect the language of the given text.
  /// FAIL-CLOSED: unknown → TranslationLanguage.unknown.
  Future<TranslationLanguage> detectLanguage(String text);

  /// Check whether the translation subsystem is available.
  Future<bool> isAvailable();

  /// Get supported language pairs.
  /// FAIL-CLOSED: unavailable → empty list.
  List<TranslationLanguage> supportedLanguages();

  /// Get confidence threshold for auto-accept.
  double get confidenceThreshold;
}
