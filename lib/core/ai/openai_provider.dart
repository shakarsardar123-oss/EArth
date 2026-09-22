import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../domain/services/ai_service.dart';
import '../../services/ai/ai_provider.dart';
import '../../core/ai/ai_message.dart';
import '../../core/ai/ai_connection_storage.dart';
import '../../core/ai/provider_exception.dart';
import '../../core/ai/endpoint_validator.dart';
import '../../core/ai/model_discovery.dart';
import '../errors/result.dart';

/// Secure storage key for the OpenAI API key.
const _apiKeyStorageKey = 'aura_openai_api_key';

/// Default OpenAI-compatible base URL.
const _defaultBaseUrl = 'https://api.openai.com/v1';

/// Secure storage key for the base URL.
const _baseUrlStorageKey = 'aura_openai_base_url';

/// Real OpenAI-compatible AI provider implementation.
///
/// Makes actual HTTP requests to an OpenAI-compatible API endpoint.
/// API key and base URL are stored securely in FlutterSecureStorage.
/// Implements exponential backoff for rate limiting (429) and transient errors (5xx).
class OpenAIProvider implements AIProvider, ModelDiscovery {
  OpenAIProvider({
    required this.secureStorage,
    this.connectionStorage,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final FlutterSecureStorage secureStorage;

  /// Optional [AIConnectionStorage] for reading the user-configured model.
  /// When null, the provider falls back to [request.agentConfig.modelId]
  /// for backward compatibility.
  final AIConnectionStorage? connectionStorage;

  final http.Client _httpClient;

  /// Maximum number of retries for transient failures (5xx, 429).
  static const int _maxRetries = 3;

  /// Initial backoff delay in milliseconds.
  static const int _initialBackoffMs = 1000;

  @override
  String get id => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  bool supportsModel(String modelId) => supportedModels.contains(modelId);

  @override
  List<String> get supportedModels => const [
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'gpt-4',
        'gpt-3.5-turbo',
        'gpt-3.5-turbo-16k',
      ];

  /// Retrieves the stored API key from secure storage.
  Future<String?> getApiKey() => secureStorage.read(key: _apiKeyStorageKey);

  /// Stores the API key in secure storage.
  Future<void> setApiKey(String key) =>
      secureStorage.write(key: _apiKeyStorageKey, value: key);

  /// Deletes the stored API key.
  Future<void> deleteApiKey() => secureStorage.delete(key: _apiKeyStorageKey);

  /// Retrieves the stored base URL from secure storage.
  Future<String> getBaseUrl() async {
    final url = await secureStorage.read(key: _baseUrlStorageKey);
    return url ?? _defaultBaseUrl;
  }

  /// Stores a custom base URL in secure storage.
  ///
  /// Validates that [url] uses HTTPS and is well-formed before storing.
  /// Throws [AIProviderException] if validation fails.
  /// Does NOT rewrite URLs — rejects insecure schemes outright.
  Future<void> setBaseUrl(String url) async {
    final result = EndpointValidator.validate(url);
    result.when(
      success: (validated) async {
        await secureStorage.write(
          key: _baseUrlStorageKey,
          value: validated,
        );
      },
      failure: (failure) {
        throw AIProviderException(
          message: failure.verdictReason ?? failure.message,
          errorCode: 'INVALID_BASE_URL',
          providerId: id,
        );
      },
    );
  }

  /// Helper: exponential backoff duration for retry attempt [attempt] (0-indexed).
  Duration _backoffDuration(int attempt) {
    // 1000ms, 2000ms, 4000ms for attempts 0, 1, 2
    final ms = _initialBackoffMs * (1 << attempt);
    // Add ±10% jitter to avoid thundering herd
    final jitter = (ms * 0.1 * (2 * (DateTime.now().microsecond % 100) / 100 - 1)).toInt();
    return Duration(milliseconds: (ms + jitter).toInt());
  }

  /// Helper: check if status code is retryable (429 rate limit or 5xx).
  bool _isRetryableStatus(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  /// Performs a single completion request with exponential backoff retry.
  ///
  /// Retries on:
  /// - 429 (Rate Limit) — waits and retries
  /// - 5xx (Server Error) — waits and retries
  ///
  /// Does NOT retry on:
  /// - 401 (No API key) — throws immediately
  /// - 403 (Forbidden) — throws immediately
  /// - 400 (Bad request) — throws immediately
  /// - Network timeouts — throws immediately
  @override
  Future<AIResponse> complete(AIRequest request) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw AIProviderException(
        message: 'OpenAI API key not configured. Please set it in Settings.',
        statusCode: 401,
        errorCode: 'NO_API_KEY',
        providerId: id,
      );
    }

    final baseUrl =
        EndpointValidator.normalizeTrailingSlash(await getBaseUrl());
    final model = connectionStorage?.getModel() ?? request.agentConfig.modelId;
    final temperature = request.temperature ?? request.agentConfig.temperature;
    final maxTokens = request.maxTokens ?? request.agentConfig.maxTokens;

    final body = <String, dynamic>{
      'model': model,
      'messages': _buildMessages(request),
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    final tools = _buildTools(request.toolDefinitions);
    if (tools != null) {
      body['tools'] = tools;
    }

    final stopwatch = Stopwatch()..start();
    AIProviderException? lastException;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _httpClient
            .post(
              Uri.parse('$baseUrl/chat/completions'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 120));

        stopwatch.stop();

        if (response.statusCode != 200) {
          String message =
              'API request failed with status ${response.statusCode}';
          String? errorCode;
          final responseBody = response.body;
          if (responseBody.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(responseBody);
              if (decoded is Map<String, dynamic>) {
                final error = decoded['error'];
                if (error is Map<String, dynamic>) {
                  message = error['message'] as String? ?? message;
                  errorCode = error['code']?.toString() ??
                      error['type']?.toString();
                } else if (error is String && error.isNotEmpty) {
                  message = error;
                }
              }
            } on FormatException {
              final snippet =
                  responseBody.trim().replaceAll(RegExp(r'\s+'), ' ');
              message =
                  'API request failed with status ${response.statusCode}: '
                  '${snippet.substring(0, snippet.length.clamp(0, 200))}';
            }
          }

          final exception = AIProviderException(
            message: message,
            statusCode: response.statusCode,
            errorCode: errorCode,
            providerId: id,
          );

          // If retryable and not last attempt, wait and retry.
          if (_isRetryableStatus(response.statusCode) &&
              attempt < _maxRetries) {
            lastException = exception;
            final backoff = _backoffDuration(attempt);
            await Future.delayed(backoff);
            continue;
          }

          // Not retryable or last attempt — throw.
          throw exception;
        }

        // 200 OK — parse response
        Map<String, dynamic> data;
        try {
          if (response.body.trim().isEmpty) {
            throw AIProviderException(
              message: 'OpenAI API returned 200 with an empty response body',
              statusCode: 200,
              errorCode: 'EMPTY_RESPONSE',
              providerId: id,
            );
          }
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } on FormatException {
          throw AIProviderException(
            message: 'OpenAI API returned 200 but the body is not valid JSON',
            statusCode: 200,
            errorCode: 'INVALID_JSON',
            providerId: id,
          );
        }

        final choices = data['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw AIProviderException(
            message: 'OpenAI API returned no choices in the response',
            statusCode: 200,
            errorCode: 'NO_CHOICES',
            providerId: id,
          );
        }

        final choice = choices.first as Map<String, dynamic>;
        final message = choice['message'] as Map<String, dynamic>;
        final content = message['content'] as String? ?? '';
        final toolCalls = message['tool_calls'] as List<dynamic>?;
        final usage = data['usage'] as Map<String, dynamic>?;

        final aiResponse = AIResponse(
          text: content,
          modelId: data['model'] as String? ?? model,
          conversationId: request.conversationId,
          finishReason: choice['finish_reason'] as String?,
          latencyMs: stopwatch.elapsedMilliseconds,
          usage: usage != null
              ? AIUsage(
                  promptTokens: usage['prompt_tokens'] as int? ?? 0,
                  completionTokens: usage['completion_tokens'] as int? ?? 0,
                  totalTokens: usage['total_tokens'] as int? ?? 0,
                )
              : null,
        );

        if (toolCalls != null && toolCalls.isNotEmpty) {
          aiResponse.toolCalls = toolCalls
              .map((tc) => AIToolCall.fromMap(tc as Map<String, dynamic>))
              .toList();
        }

        return aiResponse;
      } on AIProviderException {
        rethrow;
      } on http.ClientException catch (e) {
        throw AIProviderException(
          message: 'Network error: ${e.message}',
          providerId: id,
          originalError: e,
        );
      } on TimeoutException {
        throw AIProviderException(
          message: 'Request timed out after 120 seconds',
          providerId: id,
          errorCode: 'TIMEOUT',
        );
      } catch (e) {
        throw AIProviderException(
          message: 'Unexpected error: $e',
          providerId: id,
          originalError: e,
        );
      }
    }

    // Should not reach here, but if we do, throw the last exception
    throw lastException ??
        AIProviderException(
          message: 'Max retries exceeded',
          providerId: id,
          errorCode: 'MAX_RETRIES_EXCEEDED',
        );
  }

  @override
  Stream<AIResponse> streamComplete(AIRequest request) async* {
    final response = await complete(request);
    yield response;
  }

  /// Discovers models via the OpenAI-compatible `GET /models` endpoint.
  ///
  /// Also implements exponential backoff for rate limiting and transient errors.
  @override
  Future<List<AIModelInfo>> listModels() async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw AIProviderException(
        message: 'OpenAI API key not configured. Please set it in Settings.',
        statusCode: 401,
        errorCode: 'NO_API_KEY',
        providerId: id,
      );
    }

    final baseUrl =
        EndpointValidator.normalizeTrailingSlash(await getBaseUrl());

    AIProviderException? lastException;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _httpClient
            .get(
              Uri.parse('$baseUrl/models'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          String message =
              'OpenAI model discovery failed with status ${response.statusCode}';
          String? errorCode;
          final body = response.body;
          if (body.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(body);
              if (decoded is Map<String, dynamic>) {
                final error = decoded['error'];
                if (error is Map<String, dynamic>) {
                  message = error['message'] as String? ?? message;
                  errorCode = error['code']?.toString() ??
                      error['type']?.toString();
                }
              }
            } on FormatException {
              // Keep status-based message
            }
          }

          final exception = AIProviderException(
            message: message,
            statusCode: response.statusCode,
            errorCode: errorCode,
            providerId: id,
          );

          if (_isRetryableStatus(response.statusCode) &&
              attempt < _maxRetries) {
            lastException = exception;
            final backoff = _backoffDuration(attempt);
            await Future.delayed(backoff);
            continue;
          }

          throw exception;
        }

        Map<String, dynamic> data;
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } on FormatException {
          throw AIProviderException(
            message: 'OpenAI model discovery returned a non-JSON body',
            statusCode: 200,
            errorCode: 'INVALID_JSON',
            providerId: id,
          );
        }

        final rawModels = data['data'] as List<dynamic>? ?? const [];
        final result = <AIModelInfo>[];
        for (final raw in rawModels) {
          if (raw is! Map<String, dynamic>) continue;
          final modelId = raw['id'] as String? ?? '';
          if (modelId.isEmpty) continue;
          final category = _categorize(modelId);
          result.add(AIModelInfo(
            id: modelId,
            rawId: modelId,
            category: category,
            supportsChat: category == AIModelCategory.chat,
            supportsTools: category == AIModelCategory.chat &&
                (modelId.startsWith('gpt-4') ||
                    modelId.startsWith('gpt-3.5')),
          ));
        }
        return result;
      } on AIProviderException {
        rethrow;
      } on http.ClientException catch (e) {
        throw AIProviderException(
          message: 'Network error during model discovery: ${e.message}',
          providerId: id,
          originalError: e,
        );
      } on TimeoutException {
        throw AIProviderException(
          message: 'Model discovery timed out',
          providerId: id,
          errorCode: 'TIMEOUT',
        );
      } catch (e) {
        throw AIProviderException(
          message: 'Unexpected error during model discovery: $e',
          providerId: id,
          originalError: e,
        );
      }
    }

    throw lastException ??
        AIProviderException(
          message: 'Max retries exceeded for model discovery',
          providerId: id,
          errorCode: 'MAX_RETRIES_EXCEEDED',
        );
  }

  /// Classifies an OpenAI model id into a coarse capability category.
  static AIModelCategory _categorize(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('embedding') || lower.contains('embed')) {
      return AIModelCategory.embedding;
    }
    if (lower.contains('dall-e') ||
        lower.contains('dalle') ||
        lower.contains('image')) {
      return AIModelCategory.image;
    }
    if (lower.contains('whisper') ||
        lower.contains('tts') ||
        lower.contains('audio') ||
        lower.contains('transcribe') ||
        lower.contains('realtime')) {
      return AIModelCategory.audio;
    }
    if (lower.contains('moderation')) return AIModelCategory.moderation;
    if (lower.startsWith('davinci') ||
        lower.startsWith('babbage') ||
        lower.startsWith('ada') ||
        lower.startsWith('curie') ||
        lower.startsWith('text-davinci') ||
        lower.startsWith('text-') ||
        lower.startsWith('code-')) {
      return AIModelCategory.other;
    }
    if (lower.startsWith('gpt-') ||
        RegExp(r'^o[1-9]').hasMatch(lower) ||
        lower.startsWith('chatgpt')) {
      return AIModelCategory.chat;
    }
    return AIModelCategory.other;
  }

  // ─── Message and tool building helpers ────────────────────────────
  // (Assuming these already exist in the original; keep them as-is)

  List<Map<String, dynamic>> _buildMessages(AIRequest request) {
    return request.messages
        .map((msg) => msg.toMap())
        .toList();
  }

  List<Map<String, dynamic>>? _buildTools(
      List<AIToolDefinition>? toolDefinitions) {
    if (toolDefinitions == null || toolDefinitions.isEmpty) return null;
    return toolDefinitions
        .map((tool) => {
              'type': 'function',
              'function': {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.parameters,
              }
            })
        .toList();
  }
}
