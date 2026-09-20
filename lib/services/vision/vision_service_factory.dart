/// vision_service_factory.dart
/// AURA Assistant — Provider-aware Vision Service Factory
///
/// Returns the correct [VisionService] implementation based on the
/// user's stored [ConnectionType]:
///   - ConnectionType.gemini → [GeminiVisionService] (native Gemini API)
///   - ConnectionType.openaiCompatible / customOpenAI → [OpenAIVisionService]
///
/// This factory replaces the hardcoded openaiVisionServiceProvider
/// in vision_providers.dart so the Vision screen automatically uses
/// the right backend based on the user's AI connection settings.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_connection_storage.dart';
import '../../core/ai/connection_type.dart';
import '../../presentation/providers/app_providers.dart'
    show aiConnectionStorageProvider;
import 'vision_service.dart';
import 'openai_vision_service.dart'
    show openaiVisionServiceProvider;
import 'gemini_vision_service.dart'
    show geminiVisionServiceProvider;

/// Provider-aware factory that returns the correct [VisionService]
/// based on the current [ConnectionType] stored in [AIConnectionStorage].
///
/// - ConnectionType.gemini → GeminiVisionService
/// - ConnectionType.openaiCompatible → OpenAIVisionService
/// - ConnectionType.customOpenAI → OpenAIVisionService
final visionServiceProvider = Provider<VisionService>((ref) {
  final connectionStorage = ref.watch(aiConnectionStorageProvider);
  final connectionType = connectionStorage.getConnectionType();

  switch (connectionType) {
    case ConnectionType.gemini:
      return ref.watch(geminiVisionServiceProvider);
    case ConnectionType.openaiCompatible:
    case ConnectionType.customOpenAI:
      return ref.watch(openaiVisionServiceProvider);
  }
});
