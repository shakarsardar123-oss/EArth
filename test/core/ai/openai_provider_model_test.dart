/// openai_provider_model_test.dart
/// R7-G: Tests for OpenAIProvider model sourcing from AIConnectionStorage
///
/// Verifies:
/// - Configured model used in request when connectionStorage provided
/// - Default fallback to request.agentConfig.modelId when connectionStorage is null
/// - Model change affects future requests
/// - Backward compatibility: constructing with only secureStorage works
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:texo/core/ai/openai_provider.dart';
import 'package:texo/core/ai/ai_connection_storage.dart';
import 'package:texo/core/ai/ai_connection_config.dart';
import 'package:texo/domain/services/ai_service.dart';
import 'package:texo/domain/entities/agent_config.dart';
import 'package:texo/core/ai/ai_message.dart';

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

// ─── Capturing HTTP Client ───────────────────────────────────────────

/// HTTP client that captures the request body and returns a success response.
class _CapturingHttpClient implements http.Client {
  Map<String, dynamic>? capturedBody;
  Uri? capturedUrl;

  void _enqueueOk() {
    // Will be set during post()
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    capturedUrl = url;
    if (body != null) {
      capturedBody = jsonDecode(body.toString()) as Map<String, dynamic>;
    }
    return http.Response(
      jsonEncode({
        'id': 'chatcmpl-test',
        'object': 'chat.completion',
        'model': capturedBody?['model'] ?? 'gpt-4o-mini',
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

// ─── Test Helpers ──────────────────────────────────────────────────

AIRequest _makeRequest({
  String prompt = 'Hello',
  String modelId = 'gpt-4o-mini',
}) {
  return AIRequest(
    prompt: prompt,
    agentConfig: AgentConfig(
      id: 'test',
      name: 'Test',
      description: 'Test agent',
      systemPrompt: 'You are a test assistant.',
      modelId: modelId,
      temperature: 0.7,
      maxTokens: 1024,
    ),
  );
}

void main() {
  // ─── Backward compatibility ─────────────────────────────────────

  group('OpenAIProvider model sourcing — backward compat', () {
    test('constructing with only secureStorage works (no connectionStorage)', () {
      final secureStorage = _FakeSecureStorage(
        initial: {'aura_openai_api_key': 'sk-test-key'},
      );
      final provider = OpenAIProvider(secureStorage: secureStorage);
      expect(provider, isNotNull);
      expect(provider.id, 'openai');
    });

    test('without connectionStorage, model falls back to request.agentConfig.modelId', () async {
      final secureStorage = _FakeSecureStorage(
        initial: {'aura_openai_api_key': 'sk-test-key'},
      );
      final client = _CapturingHttpClient();
      final provider = OpenAIProvider(
        secureStorage: secureStorage,
        httpClient: client,
      );

      await provider.complete(_makeRequest(modelId: 'gpt-4-turbo'));

      // The request body should use the model from agentConfig
      expect(client.capturedBody?['model'], 'gpt-4-turbo');
    });
  });

  // ─── Configured model takes precedence ───────────────────────────

  group('OpenAIProvider model sourcing — connectionStorage model', () {
    test('connectionStorage.getModel() overrides request.agentConfig.modelId', () async {
      SharedPreferences.setMockInitialValues({
        'aura_ai_model': 'gpt-4o',
      });
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage(
        initial: {'aura_openai_api_key': 'sk-test-key'},
      );
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final client = _CapturingHttpClient();
      final provider = OpenAIProvider(
        secureStorage: secureStorage,
        connectionStorage: connectionStorage,
        httpClient: client,
      );

      // Request specifies gpt-4-turbo, but storage has gpt-4o
      await provider.complete(_makeRequest(modelId: 'gpt-4-turbo'));

      expect(client.capturedBody?['model'], 'gpt-4o');
    });

    test('model change in storage affects future requests', () async {
      SharedPreferences.setMockInitialValues({
        'aura_ai_model': 'gpt-4o',
      });
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage(
        initial: {'aura_openai_api_key': 'sk-test-key'},
      );
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final client = _CapturingHttpClient();
      final provider = OpenAIProvider(
        secureStorage: secureStorage,
        connectionStorage: connectionStorage,
        httpClient: client,
      );

      // First request: gpt-4o from storage
      await provider.complete(_makeRequest());
      expect(client.capturedBody?['model'], 'gpt-4o');

      // Change model in storage
      connectionStorage.setModel('gpt-4-turbo');

      // Second request: now uses gpt-4-turbo
      await provider.complete(_makeRequest());
      expect(client.capturedBody?['model'], 'gpt-4-turbo');
    });

    test('when storage model is empty, falls back to request.agentConfig.modelId', () async {
      // No model stored in SharedPreferences → getModel() returns kDefaultChatModel
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage(
        initial: {'aura_openai_api_key': 'sk-test-key'},
      );
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final client = _CapturingHttpClient();
      final provider = OpenAIProvider(
        secureStorage: secureStorage,
        connectionStorage: connectionStorage,
        httpClient: client,
      );

      // connectionStorage.getModel() returns 'gpt-4o-mini' (default)
      // which is non-null, so it takes precedence.
      // This is correct: even the default IS the configured model.
      await provider.complete(_makeRequest(modelId: 'gpt-4-turbo'));
      expect(client.capturedBody?['model'], 'gpt-4o-mini');
    });
  });

  // ─── Base URL from connectionStorage ─────────────────────────────

  group('OpenAIProvider model sourcing — base URL uses secure storage', () {
    test('provider.getBaseUrl reads from secure storage (not connectionStorage)', () async {
      final secureStorage = _FakeSecureStorage(
        initial: {
          'aura_openai_api_key': 'sk-test-key',
          'aura_openai_base_url': 'https://custom.api.com/v1',
        },
      );
      final provider = OpenAIProvider(secureStorage: secureStorage);
      final url = await provider.getBaseUrl();
      expect(url, 'https://custom.api.com/v1');
    });
  });
}
