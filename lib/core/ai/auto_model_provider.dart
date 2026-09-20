/// auto_model_provider.dart
/// AURA Assistant – Phase 1: AUTO model self-healing wrapper
///
/// A thin, non-breaking [AIProvider] decorator that adds ONE behaviour on
/// top of any real provider: when a chat request fails specifically because
/// the configured model no longer exists server-side
/// ([AIProviderException.isModelNotFound]), AND the app is in AUTO model
/// mode, it transparently re-discovers the available models, deterministically
/// re-selects a compatible chat model, persists it, and retries the request
/// EXACTLY ONCE.
///
/// Guarantees (production-safety):
/// - Wraps, never replaces. All non-recovery calls are pure pass-through, so
///   dropping this wrapper in / out changes nothing else.
/// - Recovery is attempted at most ONCE per request; a second failure is
///   rethrown unchanged so callers still surface a real error.
/// - Recovery only fires for model-not-found. Auth (401/403) and rate-limit
///   (429) errors are NEVER retried — they short-circuit immediately.
/// - A USER-selected model is NEVER overwritten. Recovery is skipped unless
///   [AIConnectionStorage.isModelAuto] is true.
/// - The failed model is excluded from re-selection, and if re-selection
///   yields the same id (or nothing new), the original error is rethrown
///   rather than looping.
/// - The wrapped provider must also implement [ModelDiscovery] for recovery
///   to be possible; if it does not, this wrapper is a pure pass-through.
library;

import '../../domain/services/ai_service.dart';
import '../../services/ai/ai_provider.dart';
import 'ai_connection_storage.dart';
import 'model_discovery.dart';
import 'provider_exception.dart';

/// Wraps an [AIProvider] to add AUTO model rediscover-and-retry-once.
class AutoModelProvider implements AIProvider {
  AutoModelProvider({
    required this.inner,
    required this.storage,
    required this.preferenceOrder,
  });

  /// The real provider doing the actual HTTP work.
  final AIProvider inner;

  /// Connection storage used to read AUTO mode and persist the re-selected
  /// model. Model resolution inside [inner] reads from this same storage,
  /// so updating it here is enough to change the model used on retry.
  final AIConnectionStorage storage;

  /// Deterministic provider-specific preference order used when re-selecting
  /// (e.g. [ModelSelector.geminiPreferenceOrder]).
  final List<String> preferenceOrder;

  // ─── Pass-through metadata / config ───────────────────────

  @override
  String get id => inner.id;

  @override
  String get displayName => inner.displayName;

  @override
  List<String> get supportedModels => inner.supportedModels;

  @override
  bool supportsModel(String modelId) => inner.supportsModel(modelId);

  @override
  Future<String?> getApiKey() => inner.getApiKey();

  @override
  Future<void> setApiKey(String key) => inner.setApiKey(key);

  @override
  Future<void> deleteApiKey() => inner.deleteApiKey();

  @override
  Future<String> getBaseUrl() => inner.getBaseUrl();

  @override
  Future<void> setBaseUrl(String url) => inner.setBaseUrl(url);

  // ─── Self-healing completion ───────────────────────────

  @override
  Future<AIResponse> complete(AIRequest request) async {
    try {
      return await inner.complete(request);
    } on AIProviderException catch (e) {
      if (!await _shouldRecover(e)) rethrow;
      final recovered = await _rediscoverAndReselect(failedModel: storage.getModel());
      if (!recovered) rethrow;
      // Retry EXACTLY once. Any failure here propagates unchanged.
      return inner.complete(request);
    }
  }

  @override
  Stream<AIResponse> streamComplete(AIRequest request) async* {
    try {
      yield* inner.streamComplete(request);
    } on AIProviderException catch (e) {
      if (!await _shouldRecover(e)) rethrow;
      final recovered = await _rediscoverAndReselect(failedModel: storage.getModel());
      if (!recovered) rethrow;
      yield* inner.streamComplete(request);
    }
  }

  // ─── Recovery internals ───────────────────────────────

  /// Whether an exception is eligible for a single AUTO recovery attempt.
  Future<bool> _shouldRecover(AIProviderException e) async {
    // Never retry auth or rate-limit errors.
    if (e.isAuthError || e.isRateLimit) return false;
    // Only model-not-found is recoverable.
    if (!e.isModelNotFound) return false;
    // Never override a user-chosen model.
    if (!storage.isModelAuto()) return false;
    // Recovery requires live discovery support on the inner provider.
    return inner is ModelDiscovery;
  }

  /// Re-discovers models, selects a new compatible chat model excluding the
  /// failed one, and persists it as an AUTO selection.
  ///
  /// Returns `true` only when a DIFFERENT, valid model was chosen and stored
  /// (so the caller knows a retry is worthwhile). Any discovery failure is
  /// swallowed to `false` so the ORIGINAL error is surfaced, never a
  /// discovery error.
  Future<bool> _rediscoverAndReselect({required String failedModel}) async {
    final discovery = inner as ModelDiscovery;
    try {
      final models = await discovery.listModels();
      final chosen = ModelSelector.select(
        models,
        preferenceOrder: preferenceOrder,
        exclude: {failedModel},
      );
      if (chosen == null) return false;
      // Guard against selecting the same (case-insensitive) model again.
      if (chosen.id.toLowerCase() == failedModel.trim().toLowerCase()) {
        return false;
      }
      return await storage.setAutoSelectedModel(chosen.id);
    } on AIProviderException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
