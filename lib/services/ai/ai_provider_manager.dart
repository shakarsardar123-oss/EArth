import 'ai_provider.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';

/// Manages registered [AIProvider]s and routes requests to the
/// appropriate one based on the agent's [modelId].
class AIProviderManager {
  AIProviderManager();

  final Map<String, AIProvider> _providers = {};

  /// Registers a provider.
  void registerProvider(AIProvider provider) {
    _providers[provider.id] = provider;
  }

  /// Unregisters a provider by [id].
  void unregisterProvider(String id) {
    _providers.remove(id);
  }

  /// Returns all registered providers.
  List<AIProvider> get providers => _providers.values.toList();

  /// Resolves the provider for the given [modelId].
  ///
  /// Throws [UnexpectedFailure] if no provider matches.
  Result<AIProvider, UnexpectedFailure> resolveProvider(String modelId) {
    for (final provider in _providers.values) {
      if (provider.supportsModel(modelId)) {
        return Result.success(provider);
      }
    }
    return Result.failure(
      UnexpectedFailure(message: 'No AI provider registered for model: $modelId'),
    );
  }
}
