/// translation_orchestrator.dart
/// AURA Assistant – Step 27: Real-Time Translation Pipeline
///
/// Application-layer orchestrator for translation.
/// FAIL-CLOSED: engine unavailable → deny, low confidence → deny.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/translation_request.dart';
import '../domain/models/translation_result.dart';
import '../domain/repositories/translation_engine_repository.dart';
import '../domain/services/translation_service.dart';
import 'providers.dart';

/// Orchestrates real-time translation.
/// Delegates to TranslationService for domain logic,
/// TranslationEngineRepository for engine operations.
/// FAIL-CLOSED: any failure → deny.
class TranslationOrchestrator {
  final TranslationService _translationService;
  final TranslationEngineRepository _engineRepository;

  TranslationOrchestrator({
    required TranslationService translationService,
    required TranslationEngineRepository engineRepository,
  })  : _translationService = translationService,
        _engineRepository = engineRepository;

  /// Translate text via the engine repository.
  /// FAIL-CLOSED: engine unavailable or result blocked/low-confidence → deny.
  Future<TranslationResult> translate(TranslationRequest request) async {
    final available = await _engineRepository.isEngineAvailable();
    if (!available) {
      return TranslationResult.denied;
    }
    // Check language support
    final supported = _engineRepository.engineSupportedLanguages();
    final sourceSupported = supported.any((l) => l.code == request.sourceLanguage);
    final targetSupported = supported.any((l) => l.code == request.targetLanguage);
    if (!sourceSupported || !targetSupported) {
      return TranslationResult.denied;
    }
    final result = await _engineRepository.executeTranslation(request);
    if (result.shouldDeny) return TranslationResult.denied;
    return result;
  }

  /// Stream translations for a stream of requests.
  Stream<TranslationResult> translateStream(Stream<TranslationRequest> requests) {
    return _translationService.translateStream(requests);
  }

  /// Detect language of input text.
  Future<TranslationLanguage> detectLanguage(String text) async {
    return _engineRepository.detectLanguage(text);
  }

  /// Get supported languages from engine.
  List<TranslationLanguage> getSupportedLanguages() {
    return _engineRepository.engineSupportedLanguages();
  }

  /// Get engine identifier.
  String get engineId => _engineRepository.engineId;
}

final translationOrchestratorProvider = Provider<TranslationOrchestrator>((ref) {
  return TranslationOrchestrator(
    translationService: ref.watch(translationServiceProvider),
    engineRepository: ref.watch(translationEngineRepositoryProvider),
  );
});
