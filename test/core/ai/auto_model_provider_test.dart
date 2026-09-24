/// auto_model_provider_test.dart
/// AURA Assistant – Phase 1: tests for AUTO model self-healing wrapper +
/// AIConnectionStorage AUTO/user mode.
///
/// No network access is used: the inner provider is a controllable fake and
/// storage uses a fake secure store + mocked SharedPreferences.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:texo/core/ai/ai_connection_storage.dart';
import 'package:texo/core/ai/auto_model_provider.dart';
import 'package:texo/core/ai/model_discovery.dart';
import 'package:texo/core/ai/provider_exception.dart';
import 'package:texo/services/ai/ai_provider.dart';
import 'package:texo/domain/services/ai_service.dart';
import 'package:texo/domain/entities/agent_config.dart';

// ─── Fakes ──────────────────────────────────────────

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }
  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.remove(key);
}

/// Inner provider that fails on a configured "bad" model with the given
/// exception, succeeds otherwise, and returns a scripted discovery list.
class _FakeInnerProvider implements AIProvider, ModelDiscovery {
  _FakeInnerProvider({
    required this.storage,
    required this.failWhenModel,
    required this.failure,
    required this.discoverList,
  });

  final AIConnectionStorage storage;
  final String failWhenModel;
  final AIProviderException failure;
  final List<AIModelInfo> discoverList;

  int completeCalls = 0;
  int listModelsCalls = 0;

  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  List<String> get supportedModels => const ['a', 'b'];
  @override
  bool supportsModel(String modelId) => supportedModels.contains(modelId);
  @override
  Future<String?> getApiKey() async => 'k';
  @override
  Future<void> setApiKey(String key) async {}
  @override
  Future<void> deleteApiKey() async {}
  @override
  Future<String> getBaseUrl() async => '';
  @override
  Future<void> setBaseUrl(String url) async {}

  @override
  Future<AIResponse> complete(AIRequest request) async {
    completeCalls++;
    final model = storage.getModel();
    if (model == failWhenModel) throw failure;
    return AIResponse(text: 'ok:$model', modelId: model);
  }

  @override
  Stream<AIResponse> streamComplete(AIRequest request) async* {
    yield await complete(request);
  }

  @override
  Future<List<AIModelInfo>> listModels() async {
    listModelsCalls++;
    return discoverList;
  }
}

AIRequest _req() => const AIRequest(
      prompt: 'hi',
      agentConfig: AgentConfig(
        id: 'a',
        name: 'a',
        description: 'a',
        systemPrompt: '',
        modelId: 'x',
      ),
    );

AIModelInfo _chat(String id) =>
    AIModelInfo(id: id, rawId: id, category: AIModelCategory.chat,
        supportsChat: true);

void main() {
  late _FakeSecureStorage secure;
  late SharedPreferences prefs;
  late AIConnectionStorage storage;

  setUp(() async {
    secure = _FakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = AIConnectionStorage(
      secureStorage: secure,
      sharedPreferences: prefs,
    );
  });

  // ─── Storage AUTO / user mode ──────────────────────────

  group('AIConnectionStorage AUTO mode', () {
    test('defaults to AUTO for fresh install', () {
      expect(storage.isModelAuto(), isTrue);
      expect(storage.getModelSource(), kModelSourceAuto);
    });

    test('setAutoSelectedModel stores model and keeps AUTO', () async {
      final ok = await storage.setAutoSelectedModel('gemini-3.6-flash');
      expect(ok, isTrue);
      expect(storage.getModel(), 'gemini-3.6-flash');
      expect(storage.isModelAuto(), isTrue);
      expect(storage.getModelSource(), kModelSourceAuto);
    });

    test('setUserSelectedModel stores model and disables AUTO', () async {
      final ok = await storage.setUserSelectedModel('gemini-1.5-pro');
      expect(ok, isTrue);
      expect(storage.getModel(), 'gemini-1.5-pro');
      expect(storage.isModelAuto(), isFalse);
      expect(storage.getModelSource(), kModelSourceUser);
    });

    test('blank models are rejected without changing state', () async {
      expect(await storage.setAutoSelectedModel('  '), isFalse);
      expect(await storage.setUserSelectedModel(''), isFalse);
    });

    test('migration flag is independent of AUTO flag', () async {
      await storage.setUserSelectedModel('gemini-1.5-pro');
      expect(storage.isModelAuto(), isFalse);
    });
  });

  // ─── AutoModelProvider recovery ────────────────────────

  group('AutoModelProvider recovery', () {
    test('recovers once on model-not-found in AUTO mode, then succeeds',
        () async {
      await storage.setAutoSelectedModel('gemini-old');
      final inner = _FakeInnerProvider(
        storage: storage,
        failWhenModel: 'gemini-old',
        failure: const AIProviderException(
          message: 'model not found', statusCode: 404, providerId: 'fake',
        ),
        discoverList: [_chat('gemini-3.6-flash'), _chat('gemini-2.5-flash')],
      );
      final wrapped = AutoModelProvider(
        inner: inner,
        storage: storage,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      final resp = await wrapped.complete(_req());

      expect(resp.text, 'ok:gemini-3.6-flash');
      expect(inner.completeCalls, 2); // original + one retry
      expect(inner.listModelsCalls, 1);
      expect(storage.getModel(), 'gemini-3.6-flash');
      expect(storage.isModelAuto(), isTrue);
    });

    test('does NOT recover when model is user-selected', () async {
      await storage.setUserSelectedModel('gemini-old');
      final inner = _FakeInnerProvider(
        storage: storage,
        failWhenModel: 'gemini-old',
        failure: const AIProviderException(
          message: 'model not found', statusCode: 404, providerId: 'fake',
        ),
        discoverList: [_chat('gemini-3.6-flash')],
      );
      final wrapped = AutoModelProvider(
        inner: inner,
        storage: storage,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(() => wrapped.complete(_req()),
          throwsA(isA<AIProviderException>()));
      // No rediscovery, user model preserved.
      expect(inner.listModelsCalls, 0);
      expect(storage.getModel(), 'gemini-old');
      expect(storage.isModelAuto(), isFalse);
    });

    test('does NOT recover on auth error (401)', () async {
      await storage.setAutoSelectedModel('gemini-old');
      final inner = _FakeInnerProvider(
        storage: storage,
        failWhenModel: 'gemini-old',
        failure: const AIProviderException(
          message: 'unauthorized', statusCode: 401, providerId: 'fake',
        ),
        discoverList: [_chat('gemini-3.6-flash')],
      );
      final wrapped = AutoModelProvider(
        inner: inner,
        storage: storage,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(() => wrapped.complete(_req()),
          throwsA(isA<AIProviderException>()));
      expect(inner.listModelsCalls, 0);
    });

    test('does NOT recover on rate limit (429)', () async {
      await storage.setAutoSelectedModel('gemini-old');
      final inner = _FakeInnerProvider(
        storage: storage,
        failWhenModel: 'gemini-old',
        failure: const AIProviderException(
          message: 'too many requests', statusCode: 429, providerId: 'fake',
        ),
        discoverList: [_chat('gemini-3.6-flash')],
      );
      final wrapped = AutoModelProvider(
        inner: inner,
        storage: storage,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(() => wrapped.complete(_req()),
          throwsA(isA<AIProviderException>()));
      expect(inner.listModelsCalls, 0);
    });

    test('retries only ONCE: rethrows if replacement also missing', () async {
      await storage.setAutoSelectedModel('gemini-old');
      // Discovery only offers a model that the inner provider also rejects.
      final inner = _FakeInnerProvider(
        storage: storage,
        failWhenModel: 'gemini-old',
        failure: const AIProviderException(
          message: 'model not found', statusCode: 404, providerId: 'fake',
        ),
        // Only offers the SAME failing model -> select excludes it -> null.
        discoverList: [_chat('gemini-old')],
      );
      final wrapped = AutoModelProvider(
        inner: inner,
        storage: storage,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(() => wrapped.complete(_req()),
          throwsA(isA<AIProviderException>()));
      // Discovery ran, but no different model -> no retry.
      expect(inner.listModelsCalls, 1);
      expect(inner.completeCalls, 1);
      expect(storage.getModel(), 'gemini-old');
    });

    test('successful first call is pure pass-through (no discovery)', () async {
      await storage.setAutoSelectedModel('gemini-3.6-flash');
      final inner = _FakeInnerProvider(
        storage: storage,
        failWhenModel: 'never',
        failure: const AIProviderException(message: 'x'),
        discoverList: [_chat('gemini-3.6-flash')],
      );
      final wrapped = AutoModelProvider(
        inner: inner,
        storage: storage,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      final resp = await wrapped.complete(_req());
      expect(resp.text, 'ok:gemini-3.6-flash');
      expect(inner.completeCalls, 1);
      expect(inner.listModelsCalls, 0);
    });
  });
}
