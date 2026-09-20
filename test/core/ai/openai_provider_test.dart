import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/streamed_response.dart';
import 'package:http/src/base_request.dart';
import 'package:http/src/byte_stream.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:aura_assistant/core/ai/openai_provider.dart';
import 'package:aura_assistant/core/ai/provider_exception.dart';
import 'package:aura_assistant/domain/services/ai_service.dart';
import 'package:aura_assistant/core/ai/ai_message.dart';
import 'package:aura_assistant/domain/entities/agent_config.dart';

// ─── Fake FlutterSecureStorage ────────────────────────────────────────

/// Minimal fake [FlutterSecureStorage] for unit-testing OpenAIProvider.
///
/// Supports read/write/delete/containsKey with in-memory map.
/// Platform options are ignored (unit test has no platform channels).
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

/// Mock [http.Client] that returns a pre-configured response.
///
/// http.Client is an abstract interface class, so we use [implements].
/// Only [post] is functional; other methods throw UnimplementedError.
class _MockHttpClient implements http.Client {
  http.Response? _nextResponse;
  Exception? _nextException;

  /// Queue a successful JSON response with the given body.
  void enqueueOkResponse(Map<String, dynamic> body) {
    _nextResponse = http.Response(jsonEncode(body), 200);
    _nextException = null;
  }

  /// Queue an error response with the given status code and body.
  void enqueueErrorResponse(int statusCode, Map<String, dynamic> body) {
    _nextResponse = http.Response(jsonEncode(body), statusCode);
    _nextException = null;
  }

  /// Queue an exception to be thrown on the next request.
  void enqueueException(Exception e) {
    _nextException = e;
    _nextResponse = null;
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    if (_nextException != null) {
      throw _nextException!;
    }
    if (_nextResponse != null) {
      return _nextResponse!;
    }
    throw StateError('No response queued in _MockHttpClient');
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('GET not used in OpenAIProvider');
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw UnimplementedError('PUT not used in OpenAIProvider');
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw UnimplementedError('PATCH not used in OpenAIProvider');
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw UnimplementedError('DELETE not used in OpenAIProvider');
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('HEAD not used in OpenAIProvider');
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('read not used in OpenAIProvider');
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('readBytes not used in OpenAIProvider');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError('send not used in OpenAIProvider');
  }

  @override
  void close() {}
}

// ─── Test Helpers ──────────────────────────────────────────────────────

/// Creates a default [AIRequest] for testing.
AIRequest _makeRequest({
  String prompt = 'Hello',
  String modelId = 'gpt-4o-mini',
  double temperature = 0.7,
  int maxTokens = 1024,
  List<AIMessage>? messages,
  List<Map<String, dynamic>>? toolDefinitions,
}) {
  return AIRequest(
    prompt: prompt,
    agentConfig: AgentConfig(
      id: 'test',
      name: 'Test',
      description: 'Test agent',
      systemPrompt: 'You are a test assistant.',
      modelId: modelId,
      temperature: temperature,
      maxTokens: maxTokens,
    ),
    messages: messages,
    toolDefinitions: toolDefinitions,
  );
}

/// Builds a valid OpenAI chat completions response body.
Map<String, dynamic> _okResponseBody({
  String content = 'Hello!',
  String model = 'gpt-4o-mini',
  String finishReason = 'stop',
  int promptTokens = 10,
  int completionTokens = 5,
  List<Map<String, dynamic>>? toolCalls,
}) {
  final message = <String, dynamic>{
    'role': 'assistant',
    'content': content,
  };
  if (toolCalls != null) {
    message['tool_calls'] = toolCalls;
  }
  return {
    'id': 'chatcmpl-test',
    'object': 'chat.completion',
    'model': model,
    'choices': [
      {
        'index': 0,
        'message': message,
        'finish_reason': finishReason,
      },
    ],
    'usage': {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': promptTokens + completionTokens,
    },
  };
}

// ─── Capture Clients ──────────────────────────────────────────────────

/// Wraps [_MockHttpClient] and captures the request headers.
class _HeaderCaptureClient implements http.Client {
  final _MockHttpClient _inner;
  Map<String, String> _lastHeaders = {};

  _HeaderCaptureClient(this._inner);

  Map<String, String> get lastHeaders => _lastHeaders;

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _lastHeaders = headers ?? {};
    return _inner.post(url, headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('GET not used');
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw UnimplementedError('PUT not used');
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw UnimplementedError('PATCH not used');
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
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

/// Wraps [_MockHttpClient] and captures the request body (decoded JSON).
class _BodyCaptureClient implements http.Client {
  final _MockHttpClient _inner;
  Map<String, dynamic>? _lastBody;

  _BodyCaptureClient(this._inner);

  Map<String, dynamic>? get lastBody => _lastBody;

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    if (body != null) {
      _lastBody = jsonDecode(body.toString()) as Map<String, dynamic>;
    }
    return _inner.post(url, headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError('GET not used');
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw UnimplementedError('PUT not used');
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw UnimplementedError('PATCH not used');
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
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
  group('OpenAIProvider — construction & identity', () {
    test('id is "openai"', () {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      expect(provider.id, 'openai');
    });

    test('displayName is "OpenAI"', () {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      expect(provider.displayName, 'OpenAI');
    });

    test('supportedModels contains expected models', () {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      expect(provider.supportedModels, contains('gpt-4o'));
      expect(provider.supportedModels, contains('gpt-4o-mini'));
      expect(provider.supportedModels, contains('gpt-4-turbo'));
      expect(provider.supportedModels, contains('gpt-4'));
      expect(provider.supportedModels, contains('gpt-3.5-turbo'));
      expect(provider.supportedModels, contains('gpt-3.5-turbo-16k'));
    });

    test('supportsModel returns true for supported models', () {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      expect(provider.supportsModel('gpt-4o'), isTrue);
      expect(provider.supportsModel('gpt-4o-mini'), isTrue);
    });

    test('supportsModel returns false for unsupported models', () {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      expect(provider.supportsModel('claude-3'), isFalse);
      expect(provider.supportsModel('gemini-pro'), isFalse);
    });
  });

  group('OpenAIProvider — API key CRUD', () {
    test('getApiKey returns null when no key stored', () async {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      expect(await provider.getApiKey(), isNull);
    });

    test('setApiKey stores and getApiKey retrieves', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );
      await provider.setApiKey('sk-test-123');
      expect(await provider.getApiKey(), 'sk-test-123');
    });

    test('deleteApiKey removes the key', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );
      await provider.setApiKey('sk-test-456');
      expect(await provider.getApiKey(), 'sk-test-456');
      await provider.deleteApiKey();
      expect(await provider.getApiKey(), isNull);
    });

    test('setApiKey overwrites previous key', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );
      await provider.setApiKey('sk-old');
      await provider.setApiKey('sk-new');
      expect(await provider.getApiKey(), 'sk-new');
    });
  });

  group('OpenAIProvider — base URL handling', () {
    test('getBaseUrl returns default when none stored', () async {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      expect(await provider.getBaseUrl(), 'https://api.openai.com/v1');
    });

    test('setBaseUrl stores and getBaseUrl retrieves custom URL', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );
      await provider.setBaseUrl('https://custom.api.com/v1');
      expect(await provider.getBaseUrl(), 'https://custom.api.com/v1');
    });

    test('setBaseUrl overwrites previous URL', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );
      await provider.setBaseUrl('https://old.api.com/v1');
      await provider.setBaseUrl('https://new.api.com/v1');
      expect(await provider.getBaseUrl(), 'https://new.api.com/v1');
    });
  });

  group('OpenAIProvider — complete() — missing API key', () {
    test('throws AIProviderException with NO_API_KEY when key is null', () async {
      final provider = OpenAIProvider(
        secureStorage: _FakeSecureStorage(),
        httpClient: _MockHttpClient(),
      );
      await expectLater(
        provider.complete(_makeRequest()),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.errorCode, 'errorCode', 'NO_API_KEY')
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.providerId, 'providerId', 'openai'),
        ),
      );
    });

    test('throws AIProviderException with NO_API_KEY when key is empty', () async {
      final storage = _FakeSecureStorage();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: _MockHttpClient(),
      );
      await provider.setApiKey('');
      await expectLater(
        provider.complete(_makeRequest()),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.errorCode, 'errorCode', 'NO_API_KEY'),
        ),
      );
    });
  });

  group('OpenAIProvider — complete() — successful request', () {
    test('returns AIResponse with text, model, usage', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueOkResponse(_okResponseBody(
        content: 'Hello from GPT!',
        model: 'gpt-4o-mini',
        promptTokens: 20,
        completionTokens: 8,
      ));

      final response = await provider.complete(_makeRequest());

      expect(response.text, 'Hello from GPT!');
      expect(response.modelId, 'gpt-4o-mini');
      expect(response.finishReason, 'stop');
      expect(response.usage, isNotNull);
      expect(response.usage!.promptTokens, 20);
      expect(response.usage!.completionTokens, 8);
      expect(response.usage!.totalTokens, 28);
    });

    test('parses tool calls from response', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueOkResponse(_okResponseBody(
        content: '',
        toolCalls: [
          {
            'id': 'call_abc',
            'type': 'function',
            'function': {
              'name': 'create_alarm',
              'arguments': {'time': '07:00'},
            },
          },
        ],
      ));

      final request = _makeRequest(
        toolDefinitions: [
          {
            'type': 'function',
            'function': {
              'name': 'create_alarm',
              'description': 'Create an alarm',
              'parameters': {},
            },
          },
        ],
      );
      final response = await provider.complete(request);

      expect(response.toolCalls, isNotNull);
      expect(response.toolCalls!.length, 1);
      expect(response.toolCalls!.first.id, 'call_abc');
      expect(response.toolCalls!.first.functionName, 'create_alarm');
    });

    test('sends Authorization header with Bearer token', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final captureClient = _HeaderCaptureClient(client);
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: captureClient,
      );
      await provider.setApiKey('sk-bearer-test');
      client.enqueueOkResponse(_okResponseBody());

      await provider.complete(_makeRequest());

      expect(captureClient.lastHeaders['Authorization'], 'Bearer sk-bearer-test');
      expect(captureClient.lastHeaders['Content-Type'], 'application/json');
    });
  });

  group('OpenAIProvider — complete() — HTTP errors', () {
    test('throws AIProviderException on 401 response', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueErrorResponse(401, {
        'error': {'message': 'Invalid API key', 'code': 'invalid_api_key'},
      });

      await expectLater(
        provider.complete(_makeRequest()),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('Invalid API key')),
        ),
      );
    });

    test('throws AIProviderException on 429 rate limit', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueErrorResponse(429, {
        'error': {'message': 'Rate limit exceeded', 'code': 'rate_limit'},
      });

      await expectLater(
        provider.complete(_makeRequest()),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.isRateLimit, 'isRateLimit', isTrue),
        ),
      );
    });

    test('throws AIProviderException on 500 server error', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueErrorResponse(500, {
        'error': {'message': 'Internal server error'},
      });

      await expectLater(
        provider.complete(_makeRequest()),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.isServerError, 'isServerError', isTrue),
        ),
      );
    });

    test('throws AIProviderException on network error (ClientException)', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueException(http.ClientException('Connection refused'));

      await expectLater(
        provider.complete(_makeRequest()),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
              .having((e) => e.message, 'message', contains('Network error')),
        ),
      );
    });

    test('throws AIProviderException on TimeoutException', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueException(TimeoutException('Connection timed out'));

      await expectLater(
        provider.complete(_makeRequest()),
        throwsA(
          isA<AIProviderException>()
              .having((e) => e.errorCode, 'errorCode', 'TIMEOUT')
              .having((e) => e.message, 'message', contains('timed out')),
        ),
      );
    });
  });

  group('OpenAIProvider — complete() — request body construction', () {
    test('includes system prompt, conversation history, and user prompt', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final bodyCapture = _BodyCaptureClient(client);
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: bodyCapture,
      );
      await provider.setApiKey('sk-test');
      client.enqueueOkResponse(_okResponseBody());

      final request = _makeRequest(
        prompt: 'What is 2+2?',
        messages: [
          const AIMessage(
            role: AIMessageRole.user,
            content: 'Hello',
          ),
          const AIMessage(
            role: AIMessageRole.assistant,
            content: 'Hi there!',
          ),
        ],
      );

      await provider.complete(request);

      final body = bodyCapture.lastBody!;
      final messages = body['messages'] as List<dynamic>;
      // System + 2 history + 1 user = 4
      expect(messages.length, 4);
      expect((messages[0] as Map)['role'], 'system');
      expect((messages[0] as Map)['content'], 'You are a test assistant.');
      expect((messages[1] as Map)['role'], 'user');
      expect((messages[1] as Map)['content'], 'Hello');
      expect((messages[2] as Map)['role'], 'assistant');
      expect((messages[2] as Map)['content'], 'Hi there!');
      expect((messages[3] as Map)['role'], 'user');
      expect((messages[3] as Map)['content'], 'What is 2+2?');
    });

    test('includes model, temperature, max_tokens in body', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final bodyCapture = _BodyCaptureClient(client);
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: bodyCapture,
      );
      await provider.setApiKey('sk-test');
      client.enqueueOkResponse(_okResponseBody());

      await provider.complete(_makeRequest(
        modelId: 'gpt-4o',
        temperature: 0.5,
        maxTokens: 512,
      ));

      final body = bodyCapture.lastBody!;
      expect(body['model'], 'gpt-4o');
      expect(body['temperature'], 0.5);
      expect(body['max_tokens'], 512);
    });

    test('includes tool definitions when provided', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final bodyCapture = _BodyCaptureClient(client);
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: bodyCapture,
      );
      await provider.setApiKey('sk-test');
      client.enqueueOkResponse(_okResponseBody());

      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'get_weather',
            'description': 'Get weather',
            'parameters': {'type': 'object'},
          },
        },
      ];

      await provider.complete(_makeRequest(toolDefinitions: tools));

      final body = bodyCapture.lastBody!;
      expect(body['tools'], isNotNull);
      expect((body['tools'] as List).length, 1);
    });

    test('omits tools key when no tool definitions provided', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final bodyCapture = _BodyCaptureClient(client);
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: bodyCapture,
      );
      await provider.setApiKey('sk-test');
      client.enqueueOkResponse(_okResponseBody());

      await provider.complete(_makeRequest());

      final body = bodyCapture.lastBody!;
      expect(body.containsKey('tools'), isFalse);
    });
  });

  group('OpenAIProvider — streamComplete()', () {
    test('yields a single AIResponse chunk (simplified streaming)', () async {
      final storage = _FakeSecureStorage();
      final client = _MockHttpClient();
      final provider = OpenAIProvider(
        secureStorage: storage,
        httpClient: client,
      );
      await provider.setApiKey('sk-test');
      client.enqueueOkResponse(_okResponseBody(
        content: 'Stream chunk',
        model: 'gpt-4o-mini',
      ));

      final chunks = await provider.streamComplete(_makeRequest()).toList();

      // Current Phase 3 implementation yields a single chunk.
      expect(chunks.length, 1);
      expect(chunks.first.text, 'Stream chunk');
      expect(chunks.first.modelId, 'gpt-4o-mini');
    });
  });
}
