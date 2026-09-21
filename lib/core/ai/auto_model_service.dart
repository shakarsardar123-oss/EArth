/// auto_model_service.dart
/// AURA Assistant – Phase 1: Connect-and-auto-select-model service
///
/// Used by the Settings "Test / Connect" flow so the user NEVER has to type
/// a model id by hand. Given a provider that supports [ModelDiscovery], it:
///   1. Lists the models actually available for the configured API key,
///   2. Deterministically selects a compatible chat model via
///      [ModelSelector] (reusing the SAME preference order + capability
///      filter as the live AUTO self-healing path), and
///   3. Persists it as an AUTO selection through [AIConnectionStorage].
///
/// It reuses the provider's own discovery (which builds request URIs through
/// the provider's single-source-of-truth URI builders), so the connection
/// test exercises the exact same endpoint logic as the real chat path —
/// there is no second endpoint implementation.
library;

import '../../services/ai/ai_provider.dart';
import '../../domain/services/ai_service.dart';
import '../../domain/entities/agent_config.dart';
import 'ai_connection_storage.dart';
import 'ai_error_presenter.dart';
import 'model_discovery.dart';
import 'provider_exception.dart';

/// Outcome of a connect-and-select attempt.
class AutoModelSelectionResult {
  const AutoModelSelectionResult._({
    required this.success,
    this.selectedModel,
    this.errorCategory,
    this.error,
  });

  /// Success — [selectedModel] was discovered, selected and persisted.
  factory AutoModelSelectionResult.success(String model) =>
      AutoModelSelectionResult._(success: true, selectedModel: model);

  /// Failure — [errorCategory] describes why (already classified for the UI).
  factory AutoModelSelectionResult.failure(
    AIErrorCategory category, {
    Object? error,
  }) =>
      AutoModelSelectionResult._(
        success: false,
        errorCategory: category,
        error: error,
      );

  final bool success;
  final String? selectedModel;
  final AIErrorCategory? errorCategory;

  /// Original error (for developer logs only — never shown to users).
  final Object? error;
}

/// Discovers + selects + persists a compatible chat model for a provider.
class AutoModelService {
  AutoModelService({required this.storage});

  final AIConnectionStorage storage;

  /// Connects with [provider], discovers models, selects the best compatible
  /// chat model using [preferenceOrder], and persists it as an AUTO
  /// selection.
  ///
  /// Guarantees:
  /// - Never overwrites a USER-selected model: when the current model source
  ///   is `user` and a valid model is already stored, discovery still runs to
  ///   validate the key, but the stored model is preserved.
  /// - Provider errors are classified (never leaked raw) via
  ///   [AIErrorPresenter].
  /// - Requires the provider to implement [ModelDiscovery]; otherwise returns
  ///   an [AIErrorCategory.unknown] failure.
  Future<AutoModelSelectionResult> discoverAndSelect({
    required AIProvider provider,
    required List<String> preferenceOrder,
    bool respectUserSelection = true,
    bool verifyWithGeneration = false,
  }) async {
    if (provider is! ModelDiscovery) {
      return AutoModelSelectionResult.failure(AIErrorCategory.unknown);
    }

    try {
      final models = await (provider as ModelDiscovery).listModels();
      final chosen = ModelSelector.select(
        models,
        preferenceOrder: preferenceOrder,
      );
      if (chosen == null) {
        return AutoModelSelectionResult.failure(
          AIErrorCategory.noCompatibleModel,
        );
      }

      // Preserve an explicit user choice: the key is valid and a compatible
      // model exists, but we must not silently replace what the user picked.
      final String modelToUse;
      if (respectUserSelection && !storage.isModelAuto()) {
        modelToUse = storage.getModel();
      } else {
        final saved = await storage.setAutoSelectedModel(chosen.id);
        if (!saved) {
          return AutoModelSelectionResult.failure(AIErrorCategory.unknown);
        }
        modelToUse = chosen.id;
      }

      // Optional REAL generation check: a successful listModels() does NOT
      // prove a model actually generates. When requested, send one minimal,
      // harmless request and require a non-empty reply before declaring
      // success. Any failure here is classified (never leaked raw).
      if (verifyWithGeneration) {
        final genOk = await _verifyGeneration(provider, modelToUse);
        if (genOk != null) {
          return AutoModelSelectionResult.failure(genOk);
        }
      }

      return AutoModelSelectionResult.success(modelToUse);
    } on AIProviderException catch (e) {
      return AutoModelSelectionResult.failure(
        AIErrorPresenter.categorize(e),
        error: e,
      );
    } catch (e) {
      return AutoModelSelectionResult.failure(
        AIErrorCategory.unknown,
        error: e,
      );
    }
  }

  /// Sends ONE minimal, harmless generation request to prove the selected
  /// [model] actually produces output for this key. Returns `null` on success
  /// (non-empty reply), or the classified [AIErrorCategory] on any failure.
  Future<AIErrorCategory?> _verifyGeneration(
    AIProvider provider,
    String model,
  ) async {
    try {
      final config = AgentConfig(
        id: 'aura_connection_test',
        name: 'AURA',
        description: 'connection test',
        systemPrompt: 'You are a connectivity probe.',
        modelId: model,
        temperature: 0.0,
        maxTokens: 1024,
        isDefault: false,
        isActive: false,
      );
      final response = await provider.complete(
        AIRequest(
          prompt: 'Reply with exactly: OK',
          agentConfig: config,
          temperature: 0.0,
          maxTokens: 1024,
        ),
      );
      if (response.text.trim().isEmpty) {
        return AIErrorCategory.invalidResponse;
      }
      return null;
    } on AIProviderException catch (e) {
      return AIErrorPresenter.categorize(e);
    } catch (e) {
      return AIErrorPresenter.categorize(e);
    }
  }
}
