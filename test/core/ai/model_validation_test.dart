/// model_validation_test.dart
/// R7-G: Tests for model name validation (R7-F)
///
/// Verifies: empty, whitespace-only, trimmed, valid model names
/// at both AIConnectionStorage level and AIConnectionConfig.hasValidModel.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura_assistant/core/ai/ai_connection_config.dart';
import 'package:aura_assistant/core/ai/ai_connection_storage.dart';
import 'package:aura_assistant/core/ai/connection_type.dart';

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
  // ─── AIConnectionConfig.hasValidModel ──────────────────────────────

  group('Model validation — AIConnectionConfig.hasValidModel', () {
    test('"gpt-4o-mini" is valid', () {
      const config = AIConnectionConfig(
        connectionType: ConnectionType.openaiCompatible,
        baseUrl: kDefaultBaseUrl,
        model: 'gpt-4o-mini',
      );
      expect(config.hasValidModel, isTrue);
    });

    test('empty string is invalid', () {
      const config = AIConnectionConfig(
        connectionType: ConnectionType.openaiCompatible,
        baseUrl: kDefaultBaseUrl,
        model: '',
      );
      expect(config.hasValidModel, isFalse);
    });

    test('whitespace-only is invalid', () {
      const config = AIConnectionConfig(
        connectionType: ConnectionType.openaiCompatible,
        baseUrl: kDefaultBaseUrl,
        model: '   \t  ',
      );
      expect(config.hasValidModel, isFalse);
    });

    test('model with surrounding whitespace is valid (trim check)', () {
      const config = AIConnectionConfig(
        connectionType: ConnectionType.openaiCompatible,
        baseUrl: kDefaultBaseUrl,
        model: '  gpt-4o  ',
      );
      // trim → 'gpt-4o' → non-empty → valid
      expect(config.hasValidModel, isTrue);
    });

    test('defaults has valid model', () {
      const config = AIConnectionConfig.defaults();
      expect(config.hasValidModel, isTrue);
    });
  });

  // ─── AIConnectionStorage.setModel ─────────────────────────────────

  group('Model validation — AIConnectionStorage.setModel', () {
    late AIConnectionStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = AIConnectionStorage(
        secureStorage: _FakeSecureStorage(),
        sharedPreferences: prefs,
      );
    });

    test('empty string returns false and does not store', () {
      final result = storage.setModel('');
      expect(result, isFalse);
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('whitespace-only returns false and does not store', () {
      final result = storage.setModel('   ');
      expect(result, isFalse);
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('tab/newline-only returns false and does not store', () {
      final result = storage.setModel('\t\n');
      expect(result, isFalse);
      expect(storage.getModel(), kDefaultChatModel);
    });

    test('valid model returns true and stores trimmed value', () {
      final result = storage.setModel('  gpt-4o  ');
      expect(result, isTrue);
      expect(storage.getModel(), 'gpt-4o');
    });

    test('multiple valid models overwrite correctly', () {
      storage.setModel('gpt-4o');
      storage.setModel('gpt-4-turbo');
      expect(storage.getModel(), 'gpt-4-turbo');
    });

    test('failed setModel does not corrupt previous value', () {
      storage.setModel('gpt-4o');
      // Try to set invalid model
      storage.setModel('');
      // Previous value should be intact
      expect(storage.getModel(), 'gpt-4o');
    });
  });
}
