import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:texo/core/ai/openai_provider.dart';
import 'package:texo/core/ai/provider_exception.dart';
import 'package:texo/domain/services/ai_service.dart';
import 'package:texo/core/ai/ai_message.dart';
import 'package:texo/domain/entities/agent_config.dart';

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

// ─── Mock HTTP Client ─────────────────────────────────────────────────

class _MockHttpClient implements http.Client {
  http.Response? _nextResponse;

  void enqueueOkResponse() {
    _nextResponse = http.Response(
      jsonEncode({
        'id': 'chatcmpl-test',
        'object': 'chat.completion',
        'model': 'gpt-4o-mini',
        'choices': [
          {
            'index': 0,
            'message': {'role': 'assistant', 'content': 'OK'},
            'finish_reason': 'stop',
          },
        ],
        'usage': {
          'prompt_tokens': 5,
          'completion_tokens': 2,
          'total_tokens': 7,
        },
      }),
      200,
    );
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async =>
      _nextResponse ?? (throw StateError('No response queued'));

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('GET not used');
  }

  @override
  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    throw UnimplementedError('PUT not used');
  }

  @override
  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    throw UnimplementedError('PATCH not used');
  }

  @override
  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    throw UnimplementedError('DELETE not used');
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('HEAD not used');
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('read not used');
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('readBytes not used');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError('send not used');
  }

  @override
  void close() {}
}

// ─── Tests ────────────────────────────────────────────────────────────

void main() {
  group('API Key CRUD — full round-trip lifecycle', () {
    test('SAVE → READ: key persists in storage', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await provider.setApiKey('test_api_key_123456789');
      expect(await provider.getApiKey(), 'test_api_key_123456789');
    });

    test('READ when empty returns null', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      expect(await provider.getApiKey(), isNull);
    });

    test('UPDATE: setApiKey overwrites previous key', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await provider.setApiKey('old_key_abcdef');
      expect(await provider.getApiKey(), 'old_key_abcdef');

      await provider.setApiKey('new_key_ghijkl');
      expect(await provider.getApiKey(), 'new_key_ghijkl');

      // Old key must NOT be in raw storage
      expect(storage._store['aura_openai_api_key'], 'new_key_ghijkl');
    });

    test('DELETE: deleteApiKey removes the key', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await provider.setApiKey('test_api_key_123456789');
      expect(await provider.getApiKey(), isNotNull);

      await provider.deleteApiKey();
      expect(await provider.getApiKey(), isNull);
    });

    test('DELETE when already null is idempotent', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      // No key set — delete should not throw
      await provider.deleteApiKey();
      expect(await provider.getApiKey(), isNull);
    });

    test('Full lifecycle: SAVE → READ → UPDATE → READ → DELETE → READ', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      // SAVE
      await provider.setApiKey('sk-first-key-12345');
      // READ
      expect(await provider.getApiKey(), 'sk-first-key-12345');

      // UPDATE
      await provider.setApiKey('sk-second-key-67890');
      // READ
      expect(await provider.getApiKey(), 'sk-second-key-67890');

      // DELETE
      await provider.deleteApiKey();
      // READ
      expect(await provider.getApiKey(), isNull);
    });

    test('complete() fails with NO_API_KEY after delete', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );

      // Set key, then delete it
      await provider.setApiKey('sk-temp');
      await provider.deleteApiKey();

      // Attempting complete should fail with NO_API_KEY
      final request = AIRequest(
        prompt: 'test',
        agentConfig: AgentConfig(
          id: 't',
          name: 'T',
          description: 'test',
          systemPrompt: '',
          modelId: 'gpt-4o-mini',
          temperature: 0.7,
          maxTokens: 100,
        ),
      );

      await expectLater(
        provider.complete(request),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.errorCode, 'errorCode', 'NO_API_KEY'),
        ),
      );
    });

    test('complete() works after key re-set following delete', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );

      await provider.setApiKey('sk-first');
      await provider.deleteApiKey();
      await provider.setApiKey('sk-restored');

      client.enqueueOkResponse();

      final request = AIRequest(
        prompt: 'test',
        agentConfig: AgentConfig(
          id: 't',
          name: 'T',
          description: 'test',
          systemPrompt: '',
          modelId: 'gpt-4o-mini',
          temperature: 0.7,
          maxTokens: 100,
        ),
      );

      final response = await provider.complete(request);
      expect(response.text, 'OK');
    });
  });

  group('API Key CRUD — setBaseUrl validation', () {
    test('setBaseUrl accepts valid HTTPS URL', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await provider.setBaseUrl('https://api.openai.com/v1');
      expect(await provider.getBaseUrl(), 'https://api.openai.com/v1');
    });

    test('setBaseUrl rejects HTTP URL', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await expectLater(
        provider.setBaseUrl('http://api.openai.com/v1'),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.errorCode, 'errorCode', 'INVALID_BASE_URL')
              .having((e) => e.message, 'message', contains('Insecure scheme')),
        ),
      );

      // URL should NOT have been stored
      expect(await provider.getBaseUrl(), 'https://api.openai.com/v1'); // default
    });

    test('setBaseUrl rejects empty URL', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await expectLater(
        provider.setBaseUrl(''),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.errorCode, 'errorCode', 'INVALID_BASE_URL'),
        ),
      );
    });

    test('setBaseUrl rejects URL with embedded credentials', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await expectLater(
        provider.setBaseUrl('https://user:pass@api.openai.com/v1'),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.errorCode, 'errorCode', 'INVALID_BASE_URL')
              .having((e) => e.message, 'message', contains('credentials')),
        ),
      );
    });

    test('setBaseUrl trims whitespace from valid URL', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await provider.setBaseUrl('  https://custom.api.com/v1  ');
      expect(await provider.getBaseUrl(), 'https://custom.api.com/v1');
    });
  });

  group('API Key CRUD — error messages never contain key value', () {
    test('NO_API_KEY error does not include the key value', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      // No key set — complete should fail
      try {
        final request = AIRequest(
          prompt: 'test',
          agentConfig: AgentConfig(
            id: 't',
            name: 'T',
            description: 'test',
            systemPrompt: '',
            modelId: 'gpt-4o-mini',
            temperature: 0.7,
            maxTokens: 100,
          ),
        );
        await provider.complete(request);
        fail('Should have thrown');
      } on AIProviderException catch (e) {
        // The error message should reference 'not configured' but never the key
        expect(e.message, contains('not configured'));
        expect(e.message, isNot(contains('sk-')));
        expect(e.message, isNot(contains('test_api_key')));
      }
    });

    test('INVALID_BASE_URL error does not include API key', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );

      await provider.setApiKey('sk-secret-key-value-123');

      try {
        await provider.setBaseUrl('http://insecure.com');
        fail('Should have thrown');
      } on AIProviderException catch (e) {
        // Error should mention the URL issue but never the API key
        expect(e.message, isNot(contains('sk-secret-key-value-123')));
        expect(e.message, isNot(contains('sk-')));
      }
    });
  });
}
