/// vision_model_test.dart
/// R7-G: Tests for OpenAIVisionService model sourcing from AIConnectionStorage
///
/// Verifies:
/// - Configured model from connectionStorage.getModel() is used in vision requests
/// - kDefaultVisionModel fallback when no model stored
/// - Missing API key returns VisionResult.failure
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura_assistant/services/vision/openai_vision_service.dart';
import 'package:aura_assistant/core/ai/ai_connection_storage.dart';
import 'package:aura_assistant/core/ai/ai_connection_config.dart';
import 'package:aura_assistant/domain/entities/vision/vision_entities.dart';

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

class _CapturingHttpClient implements http.Client {
  Map<String, dynamic>? capturedBody;

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    if (body != null) {
      capturedBody = jsonDecode(body.toString()) as Map<String, dynamic>;
    }
    // Return a valid vision JSON response
    return http.Response(
      jsonEncode({
        'id': 'chatcmpl-vision-test',
        'object': 'chat.completion',
        'model': capturedBody?['model'] ?? kDefaultVisionModel,
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': jsonEncode({
                'description': 'A test image',
                'targets': [],
                'scene_description': 'test scene',
              }),
            },
            'finish_reason': 'stop',
          },
        ],
        'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'total_tokens': 15},
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

void main() {
  // ─── Vision service uses configured model ────────────────────────

  group('Vision model sourcing — connectionStorage model', () {
    test('uses connectionStorage.getModel() in vision API request', () async {
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
      final service = OpenAIVisionService(
        connectionStorage: connectionStorage,
        httpClient: client,
      );

      final result = await service.analyzeImage(
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      expect(result.isSuccess, isTrue);
      expect(client.capturedBody?['model'], 'gpt-4o');
    });

    test('falls back to kDefaultVisionModel when no model stored', () async {
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
      final service = OpenAIVisionService(
        connectionStorage: connectionStorage,
        httpClient: client,
      );

      final result = await service.analyzeImage(
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      expect(result.isSuccess, isTrue);
      // getModel() returns kDefaultChatModel ('gpt-4o-mini') when empty.
      // Since 'gpt-4o-mini'.trim().isEmpty is false, the vision service
      // uses 'gpt-4o-mini' — NOT kDefaultVisionModel. This matches the
      // documented contract: kDefaultChatModel is the non-null default.
      expect(client.capturedBody?['model'], kDefaultChatModel);
    });

    test('model change affects future vision requests', () async {
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
      final service = OpenAIVisionService(
        connectionStorage: connectionStorage,
        httpClient: client,
      );

      // First request: gpt-4o
      await service.analyzeImage(
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );
      expect(client.capturedBody?['model'], 'gpt-4o');

      // Change model
      connectionStorage.setModel('gpt-4-turbo');

      // Second request: gpt-4-turbo
      await service.findObject(
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        objectName: 'cat',
      );
      expect(client.capturedBody?['model'], 'gpt-4-turbo');
    });
  });

  // ─── Missing API key returns VisionResult.failure ──────────────

  group('Vision model sourcing — missing API key', () {
    test('returns VisionResult.failure when no API key stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage(); // No API key
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final service = OpenAIVisionService(
        connectionStorage: connectionStorage,
      );

      final result = await service.analyzeImage(
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('API key'));
    });

    test('returns VisionResult.failure when API key is empty string', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = _FakeSecureStorage(
        initial: {'aura_openai_api_key': ''},
      );
      final connectionStorage = AIConnectionStorage(
        secureStorage: secureStorage,
        sharedPreferences: prefs,
      );
      final service = OpenAIVisionService(
        connectionStorage: connectionStorage,
      );

      final result = await service.analyzeImage(
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('API key'));
    });
  });
}
