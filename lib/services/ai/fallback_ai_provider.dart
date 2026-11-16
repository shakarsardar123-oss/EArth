import '../../domain/services/ai_service.dart';
import 'ai_provider.dart';

/// Tries [primary]; on rate-limit (429) or network errors, tries [fallback].
/// All configuration getters/setters go to the primary provider.
class FallbackAIProvider implements AIProvider {
  FallbackAIProvider(this._primary, this._fallback);

  final AIProvider _primary;
  final AIProvider _fallback;

  @override
  String get id => _primary.id;

  @override
  String get displayName => _primary.displayName;

  @override
  List<String> get supportedModels => _primary.supportedModels;

  @override
  bool supportsModel(String modelId) => _primary.supportsModel(modelId);

  @override
  Future<String?> getApiKey() => _primary.getApiKey();

  @override
  Future<void> setApiKey(String key) => _primary.setApiKey(key);

  @override
  Future<void> deleteApiKey() => _primary.deleteApiKey();

  @override
  Future<String> getBaseUrl() => _primary.getBaseUrl();

  @override
  Future<void> setBaseUrl(String url) => _primary.setBaseUrl(url);

  bool _shouldFallback(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('429') ||
        t.contains('rate limit') ||
        t.contains('rate-limit') ||
        t.contains('socketexception') ||
        t.contains('timeout');
  }

  @override
  Future<AIResponse> complete(AIRequest request) async {
    try {
      return await _primary.complete(request);
    } catch (e) {
      if (!_shouldFallback(e)) rethrow;
      return _fallback.complete(request);
    }
  }

  @override
  Stream<AIResponse> streamComplete(AIRequest request) async* {
    try {
      yield* _primary.streamComplete(request);
    } catch (e) {
      if (!_shouldFallback(e)) rethrow;
      yield* _fallback.streamComplete(request);
    }
  }
}
