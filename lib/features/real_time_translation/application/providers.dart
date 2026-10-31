/// providers.dart
/// AURA Assistant – Step 27: Real-Time Translation — Riverpod providers
/// FAIL-CLOSED: every provider defaults to safe/denied on error.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/translation_request.dart';
import '../domain/repositories/translation_engine_repository.dart';
import '../domain/services/translation_service.dart';

/// Service provider — will be overridden by infrastructure.
final translationServiceProvider = Provider<TranslationService>((ref) {
  throw UnimplementedError('translationServiceProvider must be overridden');
});

/// Repository provider — will be overridden by infrastructure.
final translationEngineRepositoryProvider = Provider<TranslationEngineRepository>((ref) {
  throw UnimplementedError('translationEngineRepositoryProvider must be overridden');
});

/// Currently selected source language.
final sourceLanguageProvider = StateProvider<TranslationLanguage>(
  (ref) => TranslationLanguage.kurdishSorani,
);

/// Currently selected target language.
final targetLanguageProvider = StateProvider<TranslationLanguage>(
  (ref) => TranslationLanguage.english,
);
