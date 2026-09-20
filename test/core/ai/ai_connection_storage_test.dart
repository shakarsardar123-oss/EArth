/// ai_connection_storage_test.dart
/// R7-G: Tests for AIConnectionStorage service (R7-C)
///
/// Verifies: model CRUD, connection type CRUD, base URL read/write,
/// invalid endpoint rejection, full config save/load.
///
/// Uses fake FlutterSecureStorage and real SharedPreferences
/// (setMockInitialValues).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura_assistant/core/ai/ai_connection_storage.dart';
import 'package:aura_assistant/core/ai/ai_connection_config.dart';
import 'package:aura_assistant/core/ai/connection_type.dart';
import 'package:aura_assistant/core/ai/provider_exception.dart';

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

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.containsKey(key);
}

void main() {
  late _FakeSecureStorage secureStorage;
  late SharedPreferences prefs;
  late AIConnectionStorage storage;

  setUp(() async {
    secureStorage = _FakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = AIConnectionStorage(
      secureStorage: secureStorage,
      sharedPreferences: prefs,
    );
  });

  // ─── Model CRUD ─────────────────────────────────────────────────────

  group('AIConnectionStorage — model CRUD', () {
    test('getModel returns kDefaultChatModel when nothing stored', () {
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('setModel stores and getModel retrieves', () async {
      final result = storage.setModel('gpt-4o');
      expect(result, isTrue);
      expect(storage.getModel(), 'gpt-4o');
    });

    test('setModel overwrites previous model', () async {
      storage.setModel('gpt-4o');
      storage.setModel('gpt-4-turbo');
      expect(storage.getModel(), 'gpt-4-turbo');
    });

    test('deleteModel removes stored model, reverts to default', () async {
      storage.setModel('gpt-4o');
      storage.deleteModel();
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('deleteModel when nothing stored is safe', () async {
      storage.deleteModel();
      expect(storage.getModel(), kDefaultChatModel);
    });
  });

  // ─── Model Validation ──────────────────────────────────────────────

  group('AIConnectionStorage — model validation', () {
    test('setModel rejects empty string', () {
      final result = storage.setModel('');
      expect(result, isFalse);
      // Model should remain default (not stored)
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('setModel rejects whitespace-only string', () {
      final result = storage.setModel('   \t\n  ');
      expect(result, isFalse);
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('setModel trims leading/trailing whitespace before storing', () {
      final result = storage.setModel('  gpt-4o  ');
      expect(result, isTrue);
      expect(storage.getModel(), 'gpt-4o');
    });

    test('setModel accepts valid model name', () {
      final result = storage.setModel('gpt-4o-mini');
      expect(result, isTrue);
      expect(storage.getModel(), 'gpt-4o-mini');
    });
  });

  // ─── Legacy Gemini default model migration ───────────────────

  group('AIConnectionStorage — legacy Gemini default model migration', () {
    test('migrates legacy default gemini-1.5-flash → gemini-3.6-flash on '
        'gemini connection', () async {
      storage.setConnectionType(ConnectionType.gemini);
      storage.setModel('gemini-1.5-flash');

      final migrated = await storage.migrateLegacyGeminiDefaultModel();

      expect(migrated, isTrue);
      expect(storage.getModel(), 'gemini-3.6-flash');
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('is idempotent: second run performs no further migration', () async {
      storage.setConnectionType(ConnectionType.gemini);
      storage.setModel('gemini-1.5-flash');

      final first = await storage.migrateLegacyGeminiDefaultModel();
      final second = await storage.migrateLegacyGeminiDefaultModel();

      expect(first, isTrue);
      expect(second, isFalse);
      expect(storage.getModel(), 'gemini-3.6-flash');
    });

    test('does NOT migrate when provider is OpenAI', () async {
      storage.setConnectionType(ConnectionType.openaiCompatible);
      // Even if a legacy-looking value were stored, OpenAI must be untouched.
      storage.setModel('gpt-4o-mini');

      final migrated = await storage.migrateLegacyGeminiDefaultModel();

      expect(migrated, isFalse);
      expect(storage.getModel(), 'gpt-4o-mini');
    });

    test('does NOT migrate a user-chosen custom Gemini model', () async {
      storage.setConnectionType(ConnectionType.gemini);
      storage.setModel('gemini-1.5-pro');

      final migrated = await storage.migrateLegacyGeminiDefaultModel();

      expect(migrated, isFalse);
      expect(storage.getModel(), 'gemini-1.5-pro');
    });

    test('no-op when nothing is stored', () async {
      storage.setConnectionType(ConnectionType.gemini);

      final migrated = await storage.migrateLegacyGeminiDefaultModel();

      expect(migrated, isFalse);
      // getModel already returns the current default.
      expect(storage.getModel(), kDefaultChatModel);
    });
  });

  // ─── Connection Type CRUD ──────────────────────────────────────────

  group('AIConnectionStorage — connection type CRUD', () {
    test('getConnectionType returns openaiCompatible when nothing stored', () {
      expect(storage.getConnectionType(), ConnectionType.openaiCompatible);
    });

    test('setConnectionType stores and getConnectionType retrieves', () {
      storage.setConnectionType(ConnectionType.openaiCompatible);
      expect(storage.getConnectionType(), ConnectionType.openaiCompatible);
    });

    test('invalid stored index returns openaiCompatible', () async {
      // Write an out-of-range index directly to SharedPreferences
      await prefs.setInt(kConnectionTypeStorageKey, 999);
      expect(storage.getConnectionType(), ConnectionType.openaiCompatible);
    });

    test('negative stored index returns openaiCompatible', () async {
      await prefs.setInt(kConnectionTypeStorageKey, -1);
      expect(storage.getConnectionType(), ConnectionType.openaiCompatible);
    });
  });

  // ─── Base URL CRUD ─────────────────────────────────────────────────

  group('AIConnectionStorage — base URL CRUD', () {
    test('getBaseUrl returns kDefaultBaseUrl when nothing stored', () async {
      final url = await storage.getBaseUrl();
      expect(url, kDefaultBaseUrl);
    });

    test('setBaseUrl stores and getBaseUrl retrieves valid HTTPS URL', () async {
      await storage.setBaseUrl('https://custom.api.com/v1');
      final url = await storage.getBaseUrl();
      expect(url, 'https://custom.api.com/v1');
    });

    test('setBaseUrl overwrites previous URL', () async {
      await storage.setBaseUrl('https://first.api.com/v1');
      await storage.setBaseUrl('https://second.api.com/v1');
      final url = await storage.getBaseUrl();
      expect(url, 'https://second.api.com/v1');
    });

    test('setBaseUrl trims whitespace from valid URL', () async {
      await storage.setBaseUrl('  https://custom.api.com/v1  ');
      final url = await storage.getBaseUrl();
      expect(url, 'https://custom.api.com/v1');
    });
  });

  // ─── Base URL Validation (EndpointValidator) ──────────────────────

  group('AIConnectionStorage — base URL validation (rejects invalid)', () {
    test('setBaseUrl rejects HTTP URL', () async {
      expect(
        () => storage.setBaseUrl('http://insecure.api.com/v1'),
        throwsA(isA<AIProviderException>()),
      );
    });

    test('setBaseUrl rejects empty string', () async {
      expect(
        () => storage.setBaseUrl(''),
        throwsA(isA<AIProviderException>()),
      );
    });

    test('setBaseUrl rejects whitespace-only string', () async {
      expect(
        () => storage.setBaseUrl('   '),
        throwsA(isA<AIProviderException>()),
      );
    });

    test('setBaseUrl rejects URL with embedded credentials', () async {
      expect(
        () => storage.setBaseUrl('https://user:pass@api.com/v1'),
        throwsA(isA<AIProviderException>()),
      );
    });

    test('setBaseUrl does NOT silently rewrite http:// to https://', () async {
      expect(
        () => storage.setBaseUrl('http://api.openai.com/v1'),
        throwsA(isA<AIProviderException>()),
      );
      // Verify nothing was stored
      final url = await storage.getBaseUrl();
      expect(url, kDefaultBaseUrl);
    });

    test('setBaseUrl does NOT restrict to OpenAI domains only', () async {
      await storage.setBaseUrl('https://my-custom-llm.example.com/v1');
      final url = await storage.getBaseUrl();
      expect(url, 'https://my-custom-llm.example.com/v1');
    });
  });

  // ─── Full Config ──────────────────────────────────────────────────

  group('AIConnectionStorage — full config save/load', () {
    test('getConfig returns defaults when nothing stored', () async {
      final config = await storage.getConfig();
      expect(config.connectionType, ConnectionType.openaiCompatible);
      expect(config.baseUrl, kDefaultBaseUrl);
      expect(config.model, kDefaultChatModel);
    });

    test('saveConfig stores and getConfig retrieves', () async {
      final config = AIConnectionConfig(
        connectionType: ConnectionType.openaiCompatible,
        baseUrl: 'https://custom.api.com/v1',
        model: 'gpt-4o',
      );
      final result = await storage.saveConfig(config);
      expect(result, isTrue);

      final loaded = await storage.getConfig();
      expect(loaded.connectionType, ConnectionType.openaiCompatible);
      expect(loaded.baseUrl, 'https://custom.api.com/v1');
      expect(loaded.model, 'gpt-4o');
    });

    test('saveConfig rejects invalid base URL', () async {
      final config = AIConnectionConfig(
        connectionType: ConnectionType.openaiCompatible,
        baseUrl: 'http://insecure.api.com/v1',
        model: 'gpt-4o',
      );
      expect(
        () => storage.saveConfig(config),
        throwsA(isA<AIProviderException>()),
      );
    });
  });

  // ─── API Key NOT in SharedPreferences ────────────────────────────────

  group('AIConnectionStorage — API key is NOT in SharedPreferences', () {
    test('model key does not contain "api_key" substring', () {
      expect(kModelStorageKey, isNot(contains('api_key')));
    });

    test('connection type key does not contain "api_key" substring', () {
      expect(kConnectionTypeStorageKey, isNot(contains('api_key')));
    });

    test('base URL keys do not contain "api_key" substring', () {
      expect(kGeminiBaseUrlStorageKey, isNot(contains('api_key')));
      expect(kOpenAIBaseUrlStorageKey, isNot(contains('api_key')));
    });
  });
}
