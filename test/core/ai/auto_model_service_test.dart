/// auto_model_service_test.dart
/// AURA Assistant – Phase 1: tests for the connect-and-auto-select-model
/// service, including the OPTIONAL real-generation verification step.
///
/// No network access is used: the provider is a controllable fake and storage
/// uses a fake secure store + mocked SharedPreferences. A successful
/// listModels() must NOT be treated as proof that generation works — these
/// tests pin that behaviour down.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura_assistant/core/ai/ai_connection_storage.dart';
import 'package:aura_assistant/core/ai/ai_error_presenter.dart';
import 'package:aura_assistant/core/ai/auto_model_service.dart';
import 'package:aura_assistant/core/ai/model_discovery.dart';
import 'package:aura_assistant/core/ai/provider_exception.dart';
import 'package:aura_assistant/services/ai/ai_provider.dart';
import 'package:aura_assistant/domain/services/ai_service.dart';

// ─── Fakes ─────────────────────────────────────────────

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

/// A provider that supports discovery. `discover` either returns a scripted
/// list or throws `discoverError`; `complete` either returns
/// `generationText` or throws `generationError`.
class _FakeDiscoveryProvider implements AIProvider, ModelDiscovery {
  _FakeDiscoveryProvider({
    this.discoverList = const [],
    this.discoverError,
    this.generationText = 'OK',
    this.generationError,
  });

  final List<AIModelInfo> discoverList;
  final Object? discoverError;
  final String generationText;
  final Object? generationError;

  int listModelsCalls = 0;
  int completeCalls = 0;

  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  List<String> get supportedModels => const [];
  @override
  bool supportsModel(String modelId) => true;
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
    if (generationError != null) throw generationError!;
    return AIResponse(text: generationText, modelId: request.agentConfig.modelId);
  }

  @override
  Stream<AIResponse> streamComplete(AIRequest request) async* {
    yield await complete(request);
  }

  @override
  Future<List<AIModelInfo>> listModels() async {
    listModelsCalls++;
    if (discoverError != null) throw discoverError!;
    return discoverList;
  }
}

/// A provider that does NOT implement ModelDiscovery.
class _NoDiscoveryProvider implements AIProvider {
  @override
  String get id => 'nodisc';
  @override
  String get displayName => 'NoDisc';
  @override
  List<String> get supportedModels => const [];
  @override
  bool supportsModel(String modelId) => true;
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
  Future<AIResponse> complete(AIRequest request) async =>
      AIResponse(text: 'x', modelId: 'x');
  @override
  Stream<AIResponse> streamComplete(AIRequest request) async* {}
}

AIModelInfo _chat(String id) => AIModelInfo(
      id: id,
      rawId: id,
      category: AIModelCategory.chat,
      supportsChat: true,
    );

AIModelInfo _embed(String id) => AIModelInfo(
      id: id,
      rawId: id,
      category: AIModelCategory.embedding,
      supportsChat: false,
    );

void main() {
  late _FakeSecureStorage secure;
  late SharedPreferences prefs;
  late AIConnectionStorage storage;
  late AutoModelService service;

  setUp(() async {
    secure = _FakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = AIConnectionStorage(
      secureStorage: secure,
      sharedPreferences: prefs,
    );
    service = AutoModelService(storage: storage);
  });

  group('discoverAndSelect – discovery only', () {
    test('selects preferred chat model and persists it as AUTO', () async {
      final provider = _FakeDiscoveryProvider(
        discoverList: [_chat('gemini-2.5-flash'), _chat('gemini-3.6-flash')],
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(result.success, isTrue);
      expect(result.selectedModel, 'gemini-3.6-flash');
      expect(storage.getModel(), 'gemini-3.6-flash');
      expect(storage.isModelAuto(), isTrue);
      // No generation check requested → complete() never called.
      expect(provider.completeCalls, 0);
    });

    test('fails with noCompatibleModel when only non-chat models exist',
        () async {
      final provider = _FakeDiscoveryProvider(
        discoverList: [_embed('text-embedding-004')],
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(result.success, isFalse);
      expect(result.errorCategory, AIErrorCategory.noCompatibleModel);
    });

    test('fails with unknown when provider lacks discovery', () async {
      final result = await service.discoverAndSelect(
        provider: _NoDiscoveryProvider(),
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(result.success, isFalse);
      expect(result.errorCategory, AIErrorCategory.unknown);
    });

    test('classifies auth error from discovery (401)', () async {
      final provider = _FakeDiscoveryProvider(
        discoverError: const AIProviderException(
          message: 'unauthorized', statusCode: 401, providerId: 'fake',
        ),
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(result.success, isFalse);
      expect(result.errorCategory, AIErrorCategory.auth);
    });

    test('preserves an explicit user-selected model (validates key only)',
        () async {
      await storage.setUserSelectedModel('gemini-1.5-pro');
      final provider = _FakeDiscoveryProvider(
        discoverList: [_chat('gemini-3.6-flash')],
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      expect(result.success, isTrue);
      // Discovery ran, but user's model is untouched.
      expect(provider.listModelsCalls, 1);
      expect(result.selectedModel, 'gemini-1.5-pro');
      expect(storage.getModel(), 'gemini-1.5-pro');
      expect(storage.isModelAuto(), isFalse);
    });
  });

  group('discoverAndSelect – verifyWithGeneration', () {
    test('succeeds when discovery selects AND generation returns text',
        () async {
      final provider = _FakeDiscoveryProvider(
        discoverList: [_chat('gemini-3.6-flash')],
        generationText: 'OK',
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
        verifyWithGeneration: true,
      );

      expect(result.success, isTrue);
      expect(result.selectedModel, 'gemini-3.6-flash');
      expect(provider.listModelsCalls, 1);
      expect(provider.completeCalls, 1);
    });

    test('FAILS when discovery works but generation returns empty text',
        () async {
      final provider = _FakeDiscoveryProvider(
        discoverList: [_chat('gemini-3.6-flash')],
        generationText: '   ',
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
        verifyWithGeneration: true,
      );

      expect(result.success, isFalse);
      expect(result.errorCategory, AIErrorCategory.invalidResponse);
      expect(provider.completeCalls, 1);
    });

    test('FAILS with auth when generation throws 401 despite listModels ok',
        () async {
      final provider = _FakeDiscoveryProvider(
        discoverList: [_chat('gemini-3.6-flash')],
        generationError: const AIProviderException(
          message: 'unauthorized', statusCode: 401, providerId: 'fake',
        ),
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
        verifyWithGeneration: true,
      );

      expect(result.success, isFalse);
      expect(result.errorCategory, AIErrorCategory.auth);
    });

    test('does NOT run generation check when flag is false (default)',
        () async {
      final provider = _FakeDiscoveryProvider(
        discoverList: [_chat('gemini-3.6-flash')],
        generationError: const AIProviderException(
          message: 'unauthorized', statusCode: 401, providerId: 'fake',
        ),
      );

      final result = await service.discoverAndSelect(
        provider: provider,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );

      // Discovery-only path still succeeds; generation never attempted.
      expect(result.success, isTrue);
      expect(provider.completeCalls, 0);
    });
  });
}
