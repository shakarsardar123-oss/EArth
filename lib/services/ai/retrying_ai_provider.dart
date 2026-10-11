/// Wraps any AIProvider: on HTTP 429 / quota errors waits and retries
/// (per-minute limits). If the server says the wait is long (daily quota)
/// it gives up immediately and rethrows the original error.
library;

import 'dart:async';
import 'dart:math';

import '../../core/phone_agent/debug_toast.dart';
import '../../domain/services/ai_service.dart';
import 'ai_provider.dart';

class RetryingAIProvider implements AIProvider {
  RetryingAIProvider(this._inner, {this.maxRetries = 3});

  final AIProvider _inner;
  final int maxRetries;

  @override
  String get id => _inner.id;

  @override
  String get displayName => _inner.displayName;

  @override
  List<String> get supportedModels => _inner.supportedModels;

  @override
  bool supportsModel(String modelId) => _inner.supportsModel(modelId);

  @override
  Future<String?> getApiKey() => _inner.getApiKey();

  @override
  Future<void> setApiKey(String key) => _inner.setApiKey(key);

  @override
  Future<void> deleteApiKey() => _inner.deleteApiKey();

  @override
  Future<String> getBaseUrl() => _inner.getBaseUrl();

  @override
  Future<void> setBaseUrl(String url) => _inner.setBaseUrl(url);

  @override
  Future<AIResponse> complete(AIRequest request) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _inner.complete(request);
      } catch (e) {
        final wait = _retryDelay(e, attempt);
        if (wait == null || attempt >= maxRetries) rethrow;
        await Future<void>.delayed(wait);
      }
    }
  }

  @override
  Stream<AIResponse> streamComplete(AIRequest request) async* {
    for (var attempt = 0;; attempt++) {
      var started = false;
      try {
        await for (final r in _inner.streamComplete(request)) {
          started = true;
          yield r;
        }
        return;
      } catch (e) {
        final wait = started ? null : _retryDelay(e, attempt);
        if (wait == null || attempt >= maxRetries) rethrow;
        await Future<void>.delayed(wait);
      }
    }
  }

  Duration? _retryDelay(Object e, int attempt) {
    final t = e.toString();
    final lower = t.toLowerCase();
    final is429 = t.contains('429') ||
        t.contains('RESOURCE_EXHAUSTED') ||
        lower.contains('rate limit') ||
        lower.contains('quota');
    if (!is429) return null;

    debugToast('TEXO 429: ${t.replaceAll(RegExp(r"\s+"), " ")}');

    final m = RegExp(r'retry in ([0-9]+(?:\.[0-9]+)?)\s*s', caseSensitive: false)
            .firstMatch(t) ??
        RegExp(r'"retryDelay"\s*:\s*"([0-9]+(?:\.[0-9]+)?)s"').firstMatch(t);
    final secs = m != null
        ? double.parse(m.group(1)!) + 1
        : 4.0 * pow(2, attempt).toDouble();
    if (secs > 45) return null; // long wait = daily quota, retrying is useless
    return Duration(milliseconds: (secs * 1000).round());
  }
}
