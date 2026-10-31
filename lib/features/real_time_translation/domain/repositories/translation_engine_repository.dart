/// translation_engine_repository.dart
/// AURA Assistant – Step 27: Real-Time Translation Pipeline
///
/// Abstract repository for translation engine backends.
/// Infrastructure adapters (local Whisper, cloud API) implement this.
/// FAIL-CLOSED: error → null, unavailable → null.
library;

import '../models/translation_request.dart';
import '../models/translation_result.dart';

/// Abstract repository interface for translation engines.
abstract class TranslationEngineRepository {
  /// Execute a translation via the engine.
  /// FAIL-CLOSED: failure → TranslationResult.denied.
  Future<TranslationResult> executeTranslation(TranslationRequest request);

  /// Detect language via the engine.
  /// FAIL-CLOSED: unknown → TranslationLanguage.unknown.
  Future<TranslationLanguage> detectLanguage(String text);

  /// Check engine availability.
  Future<bool> isEngineAvailable();

  /// Get supported language pairs from the engine.
  List<TranslationLanguage> engineSupportedLanguages();

  /// Engine identifier.
  String get engineId;
}
