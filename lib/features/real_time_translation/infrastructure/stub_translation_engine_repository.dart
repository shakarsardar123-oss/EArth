/// stub_translation_engine_repository.dart
/// AURA Assistant – Step 27: Real-Time Translation
///
/// FAIL-CLOSED stub: all operations return denied/unavailable.
library;

import '../domain/models/translation_request.dart';
import '../domain/models/translation_result.dart';
import '../domain/repositories/translation_engine_repository.dart';

class StubTranslationEngineRepository implements TranslationEngineRepository {
  @override
  String get engineId => 'stub-engine';

  @override
  Future<bool> isEngineAvailable() async => false;

  @override
  List<TranslationLanguage> engineSupportedLanguages() => [];

  @override
  Future<TranslationResult> executeTranslation(TranslationRequest request) async =>
      TranslationResult.denied;

  @override
  Future<TranslationLanguage> detectLanguage(String text) async =>
      TranslationLanguage.unknown;
}
