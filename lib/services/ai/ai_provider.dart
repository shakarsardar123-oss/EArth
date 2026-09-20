import '../../domain/services/ai_service.dart';

/// Abstraction for a specific AI backend provider (e.g. OpenAI, Anthropic).
///
/// Each provider implements its own request building, authentication,
/// and response parsing logic. [AIProviderManager] orchestrates
/// provider selection based on the active agent's [modelId].
abstract class AIProvider {
  /// Unique identifier for this provider (e.g. 'openai', 'anthropic').
  String get id;

  /// Human-readable display name.
  String get displayName;

  /// List of model IDs this provider supports.
  List<String> get supportedModels;

  /// Whether this provider can handle the given [modelId].
  bool supportsModel(String modelId) => supportedModels.contains(modelId);

  /// Performs a single completion request.
  /// Retrieves the stored API key for this provider.
  Future<String?> getApiKey();

  /// Stores the API key for this provider.
  Future<void> setApiKey(String key);

  /// Deletes the stored API key for this provider.
  Future<void> deleteApiKey();

  /// Retrieves the stored base URL for this provider.
  Future<String> getBaseUrl();

  /// Stores a custom base URL for this provider.
  Future<void> setBaseUrl(String url);

  Future<AIResponse> complete(AIRequest request);

  /// Performs a streaming completion request.
  Stream<AIResponse> streamComplete(AIRequest request);
}
