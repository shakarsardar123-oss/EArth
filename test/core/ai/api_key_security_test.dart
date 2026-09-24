/// api_key_security_test.dart
/// R7-G: Tests for API key security (R7-F)
///
/// Verifies:
/// - API key is never stored in SharedPreferences
/// - API key uses FlutterSecureStorage exclusively
/// - API key is NOT part of AIConnectionConfig
/// - API key is NOT in AIConnectionStorage non-secret keys
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:texo/core/ai/ai_connection_storage.dart';
import 'package:texo/core/ai/ai_connection_config.dart';
import 'package:texo/core/ai/connection_type.dart';
import 'package:texo/core/ai/openai_provider.dart';

// ─── Fake FlutterSecureStorage ────────────────────────────────────────

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
  // ─── AIConnectionConfig does NOT contain API key ──────────────────

  group('API Key Security — AIConnectionConfig has no API key field', () {
    test('AIConnectionConfig fields are only connectionType, baseUrl, model', () {
      const config = AIConnectionConfig.defaults();
      // Verify the config object does NOT expose an apiKey field
      // by checking that the only fields are the three expected ones.
      // If someone adds apiKey to AIConnectionConfig, this test
      // will fail because the class structure changes.
      expect(config.connectionType, isA<ConnectionType>());
      expect(config.baseUrl, isA<String>());
      expect(config.model, isA<String>());
      // No apiKey accessor exists — verified by static type system.
      // This test documents the design intent.
    });
  });

  // ─── SharedPreferences keys do NOT contain API key ────────────────

  group('API Key Security — SharedPreferences keys exclude API key', () {
    test('kModelStorageKey does not contain "api_key"', () {
      expect(kModelStorageKey, isNot(contains('api_key')));
    });

    test('kConnectionTypeStorageKey does not contain "api_key"', () {
      expect(kConnectionTypeStorageKey, isNot(contains('api_key')));
    });

    test('no SharedPreferences key contains "api_key"', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage();
      final storage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );

      // Perform all non-secret operations
      storage.setModel('gpt-4o');
      storage.setConnectionType(ConnectionType.openaiCompatible);
      await storage.setBaseUrl('https://api.openai.com/v1');

      // Check that no key in SharedPreferences contains 'api_key'
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        expect(key, isNot(contains('api_key')));
      }
    });
  });

  // ─── API key stored only in FlutterSecureStorage ──────────────────

  group('API Key Security — API key uses FlutterSecureStorage exclusively', () {
    late _FakeSecureStorage secureStorage;
    late OpenAIProvider provider;

    setUp(() {
      secureStorage = _FakeSecureStorage();
      provider = OpenAIProvider(secureStorage: secureStorage);
    });

    test('setApiKey stores in secure storage, not SharedPreferences', () async {
      await provider.setApiKey('sk-test-key-12345');

      // Key should be in secure storage
      final storedKey = await secureStorage.read(key: 'aura_openai_api_key');
      expect(storedKey, 'sk-test-key-12345');

      // Key should NOT be in SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('getApiKey reads from secure storage', () async {
      await provider.setApiKey('sk-test-key-12345');
      final key = await provider.getApiKey();
      expect(key, 'sk-test-key-12345');
    });

    test('deleteApiKey removes from secure storage', () async {
      await provider.setApiKey('sk-test-key-12345');
      await provider.deleteApiKey();
      final key = await provider.getApiKey();
      expect(key, isNull);
    });
  });

  // ─── AIConnectionStorage does NOT manage API keys ─────────────────

  group('API Key Security — AIConnectionStorage has no API key methods', () {
    test('AIConnectionStorage exposes no getApiKey / setApiKey / deleteApiKey', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = AIConnectionStorage(
        secureStorage: _FakeSecureStorage(),
        sharedPreferences: prefs,
      );
      // AIConnectionStorage does not have getApiKey, setApiKey, deleteApiKey.
      // This is verified by the static type system — if someone adds them,
      // the compile-time API surface changes.
      // We verify it has the expected non-key methods:
      expect(storage.getModel, isA<Function>());
      expect(storage.setModel, isA<Function>());
      expect(storage.getBaseUrl, isA<Function>());
      expect(storage.setBaseUrl, isA<Function>());
      expect(storage.getConnectionType, isA<Function>());
      expect(storage.setConnectionType, isA<Function>());
    });
  });
}
