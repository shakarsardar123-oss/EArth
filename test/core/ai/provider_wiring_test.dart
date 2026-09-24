/// provider_wiring_test.dart
/// R7-G: Tests for Riverpod provider wiring — AIConnectionStorage
///
/// Verifies:
/// - aiConnectionStorageProvider can be constructed with overrides
/// - openaiVisionServiceProvider resolves from aiConnectionStorageProvider
/// - No circular dependency between providers
/// - Existing API key CRUD still works (regression guard)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:texo/presentation/providers/app_providers.dart';
import 'package:texo/presentation/providers/vision_providers.dart'
    show openaiVisionServiceProvider;
import 'package:texo/core/ai/ai_connection_storage.dart';
import 'package:texo/core/ai/openai_provider.dart'
    hide openaiProviderProvider;
import 'package:texo/services/vision/openai_vision_service.dart';
import 'package:texo/services/ai/ai_provider.dart'
    show AIProvider;

// ─── Fake FlutterSecureStorage ────────────────────────────────────────

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};

  _FakeSecureStorage({Map<String, String>? initial}) {
    if (initial != null) _store.addAll(initial);
  }

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
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
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
  }) async {
    _store.remove(key);
  }
}

void main() {
  // ─── Provider construction ──────────────────────────────────────────

  group('Provider wiring — aiConnectionStorageProvider', () {
    test('can be constructed with overrides', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage();
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          flutterSecureStorageProvider.overrideWithValue(secureStorage),
          aiConnectionStorageProvider.overrideWithValue(connectionStorage),
        ],
      );

      // Should not throw
      final storage = container.read(aiConnectionStorageProvider);
      expect(storage, isA<AIConnectionStorage>());
      expect(storage, same(connectionStorage));

      container.dispose();
    });

    test('getModel returns default when nothing stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage();
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          flutterSecureStorageProvider.overrideWithValue(secureStorage),
          aiConnectionStorageProvider.overrideWithValue(connectionStorage),
        ],
      );

      final storage = container.read(aiConnectionStorageProvider);
      expect(storage.getModel(), 'gemini-3.6-flash'); // kDefaultChatModel

      container.dispose();
    });
  });

  // ─── Vision provider wiring ───────────────────────────────────────

  group('Provider wiring — openaiVisionServiceProvider', () {
    test('resolves from aiConnectionStorageProvider without circular deps',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage();
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          flutterSecureStorageProvider.overrideWithValue(secureStorage),
          aiConnectionStorageProvider.overrideWithValue(connectionStorage),
        ],
      );

      // Reading the vision provider should not cause a circular dep error
      final visionService = container.read(openaiVisionServiceProvider);
      expect(visionService, isA<OpenAIVisionService>());
      // Verify it uses the same connectionStorage
      expect(visionService.connectionStorage, same(connectionStorage));

      container.dispose();
    });
  });

  // ─── OpenAI provider wiring ──────────────────────────────────────

  group('Provider wiring — openaiProviderProvider', () {
    test('can be constructed with connectionStorage override', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage(
        initial: {'aura_openai_api_key': 'sk-test-key'},
      );
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final provider = OpenAIProvider(
        secureStorage: secureStorage,
        connectionStorage: connectionStorage,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          flutterSecureStorageProvider.overrideWithValue(secureStorage),
          aiConnectionStorageProvider.overrideWithValue(connectionStorage),
          openaiProviderProvider.overrideWithValue(provider),
        ],
      );

      final resolvedProvider = container.read(openaiProviderProvider);
      expect(resolvedProvider, isA<AIProvider>());
      expect(resolvedProvider.id, 'openai');

      container.dispose();
    });
  });

  // ─── Regression: API key CRUD still works through provider ─────────

  group('Provider wiring — API key CRUD regression', () {
    test('setApiKey and getApiKey work through OpenAIProvider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage();
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final provider = OpenAIProvider(
        secureStorage: secureStorage,
        connectionStorage: connectionStorage,
      );

      // Set key
      await provider.setApiKey('sk-new-key-123');
      final key = await provider.getApiKey();
      expect(key, 'sk-new-key-123');

      // Delete key
      await provider.deleteApiKey();
      final deletedKey = await provider.getApiKey();
      expect(deletedKey, isNull);
    });

    test('API key is not in SharedPreferences after setApiKey', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage();
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final provider = OpenAIProvider(
        secureStorage: secureStorage,
        connectionStorage: connectionStorage,
      );

      await provider.setApiKey('sk-another-key');

      // SharedPreferences should have model/connectionType keys but NOT api_key
      final allKeys = prefs.getKeys();
      for (final k in allKeys) {
        expect(k, isNot(contains('api_key')));
      }
    });
  });
}
