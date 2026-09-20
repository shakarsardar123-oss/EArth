import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/vision/vision_entities.dart';
import '../../core/ai/ai_connection_config.dart' show kDefaultVisionModel;
import '../../core/ai/ai_connection_storage.dart';
import '../../core/ai/endpoint_validator.dart';
import '../../presentation/providers/app_providers.dart' show aiConnectionStorageProvider;
import 'vision_service.dart';
import '../../core/errors/result.dart';

/// Secure storage key for API key (shared with OpenAIProvider).
const _apiKeyStorageKey = 'aura_openai_api_key';

/// Maximum tokens for vision responses.
const _maxTokens = 1024;

/// Temperature for vision analysis.
const _temperature = 0.3;

/// OpenAI gpt-4o vision implementation of [VisionService].
///
/// Bypasses AIMessage (which only supports string content) and builds
/// raw multimodal message content arrays with type:image_url entries.
class OpenAIVisionService implements VisionService {
  OpenAIVisionService({
    required this.connectionStorage,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// [AIConnectionStorage] provides the user-configured model,
  /// base URL, and API key (via secureStorage).
  final AIConnectionStorage connectionStorage;

  /// Convenience accessor for secure storage (API key reads).
  FlutterSecureStorage get secureStorage => connectionStorage.secureStorage;

  final http.Client _httpClient;

  @override
  Future<bool> isAvailable() async {
    final apiKey = await connectionStorage.secureStorage.read(key: _apiKeyStorageKey);
    return apiKey != null && apiKey.isNotEmpty;
  }

  @override
  Future<VisionResult> analyzeImage({
    required String imageBase64,
    String? prompt,
  }) async {
    const systemPrompt = '''You are a helpful vision assistant. Analyze the provided image and give a comprehensive description.
Identify all objects, people, text, and scene elements.
For each detected item, provide its location using normalized bounding box coordinates (0.0–1.0).
Respond in JSON format:
{
  "description": "overall description of the image",
  "scene_description": "what kind of scene this is",
  "targets": [
    {
      "type": "object|text|person|scene_element|animal|vehicle|food|other",
      "label": "short name",
      "description": "detailed description",
      "bounding_box": {
        "x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0,
        "style": "rect|circle|arrow|point",
        "label": "name",
        "confidence": 0.9
      },
      "confidence": 0.9
    }
  ],
  "ocr_text": "any text found in the image"
}''';

    final userContent = prompt ?? 'Analyze this image in detail. Identify all objects, people, text, and describe the scene.';

    return _callVisionAPI(
      systemPrompt: systemPrompt,
      userText: userContent,
      imageBase64: imageBase64,
    );
  }

  @override
  Future<VisionResult> findObject({
    required String imageBase64,
    required String objectName,
  }) async {
    final systemPrompt = '''You are a vision assistant. Find the object described by the user in the image.
If found, provide its location as a normalized bounding box (0–1).
Respond in JSON:
{
  "description": "description of what you found",
  "targets": [
    {
      "type": "object",
      "label": "$objectName",
      "description": "detailed description",
      "bounding_box": {
        "x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0,
        "style": "rect",
        "label": "$objectName",
        "confidence": 0.9
      },
      "confidence": 0.9
    }
  ]
}
If the object is NOT found, respond with:
{
  "description": "Object not found in the image",
  "targets": []
}''';

    return _callVisionAPI(
      systemPrompt: systemPrompt,
      userText: 'Find "$objectName" in this image. Provide its exact location.',
      imageBase64: imageBase64,
    );
  }

  @override
  Future<VisionResult> readText({
    required String imageBase64,
    String? language,
  }) async {
    final langHint = language != null ? ' The text may be in $language language.' : '';
    final systemPrompt = '''You are an OCR assistant. Read all visible text in the image.$langHint
Provide the extracted text and the location of each text region.
Respond in JSON:
{
  "description": "summary of text content",
  "ocr_text": "full extracted text",
  "targets": [
    {
      "type": "text",
      "label": "short text snippet",
      "description": "full text in this region",
      "bounding_box": {
        "x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0,
        "style": "rect",
        "label": "text",
        "confidence": 0.9
      },
      "confidence": 0.9
    }
  ]
}''';

    return _callVisionAPI(
      systemPrompt: systemPrompt,
      userText: 'Read all visible text in this image. Provide the text content and locations.',
      imageBase64: imageBase64,
    );
  }

  @override
  Future<VisionResult> describeScene({
    required String imageBase64,
  }) async {
    const systemPrompt = '''You are a scene description assistant. Describe the overall scene in the image.
Respond in JSON:
{
  "description": "overall description",
  "scene_description": "what kind of scene (indoor/outdoor, type of location, etc.)",
  "targets": [
    {
      "type": "scene_element",
      "label": "element name",
      "description": "what this element is",
      "bounding_box": {
        "x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0,
        "style": "rect",
        "label": "element",
        "confidence": 0.9
      },
      "confidence": 0.9
    }
  ]
}''';

    return _callVisionAPI(
      systemPrompt: systemPrompt,
      userText: 'Describe this scene in detail. What kind of place is this? What is happening?',
      imageBase64: imageBase64,
    );
  }

  @override
  Future<VisionResult> locateTarget({
    required String imageBase64,
    required String targetDescription,
    String overlayStyle = 'rect',
  }) async {
    final systemPrompt = '''You are a target-locating assistant. Find the described target in the image.
Provide its location as a normalized bounding box (0–1) for visual overlay.
Use the "$overlayStyle" overlay style.
Respond in JSON:
{
  "description": "what you found and where",
  "targets": [
    {
      "type": "object",
      "label": "target name",
      "description": "detailed description",
      "bounding_box": {
        "x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0,
        "style": "$overlayStyle",
        "label": "target",
        "confidence": 0.9
      },
      "confidence": 0.9
    }
  ]
}
If the target is NOT found, respond with:
{
  "description": "Target not found in the image",
  "targets": []
}''';

    return _callVisionAPI(
      systemPrompt: systemPrompt,
      userText: 'Locate "$targetDescription" in this image. Show me exactly where it is.',
      imageBase64: imageBase64,
    );
  }

  /// Core vision API call — builds raw multimodal messages with image_url content.
  ///
  /// This bypasses AIMessage.toMap() which only produces string content.
  Future<VisionResult> _callVisionAPI({
    required String systemPrompt,
    required String userText,
    required String imageBase64,
  }) async {
    final apiKey = await connectionStorage.secureStorage.read(key: _apiKeyStorageKey);
    if (apiKey == null || apiKey.isEmpty) {
      return VisionResult.failure('OpenAI API key not configured. Please set it in Settings.');
    }

    // Use user-configured model, fallback to default vision model.
    final model = connectionStorage.getModel().trim().isEmpty
        ? kDefaultVisionModel
        : connectionStorage.getModel();

    final baseUrl = EndpointValidator.normalizeTrailingSlash(
        await connectionStorage.getBaseUrl());

    // Build raw multimodal messages — content as array with text + image_url.
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': systemPrompt,
      },
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text': userText,
          },
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$imageBase64',
              'detail': 'auto',
            },
          },
        ],
      },
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'max_tokens': _maxTokens,
      'temperature': _temperature,
    };

    final stopwatch = Stopwatch()..start();

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
        final errorBody =
            jsonDecode(response.body) as Map<String, dynamic>;
        final errorMsg = errorBody['error']?['message'] as String? ??
            'Vision API request failed with status ${response.statusCode}';
        return VisionResult.failure(errorMsg);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choice =
          (data['choices'] as List<dynamic>).first as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>;
      final content = message['content'] as String? ?? '';
      final modelUsed = data['model'] as String? ?? model;

      return _parseVisionResponse(
        rawContent: content,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        modelUsed: modelUsed,
        rawResponse: data,
      );
    } on TimeoutException {
      return VisionResult.failure('Vision API request timed out after 120 seconds');
    } on SocketException catch (e) {
      return VisionResult.failure('Network error: ${e.message}');
    } on FormatException catch (e) {
      return VisionResult.failure('Invalid response format: ${e.message}');
    } catch (e) {
      return VisionResult.failure('Vision API error: $e');
    }
  }

  /// Parse the AI response content into a structured VisionResult.
  ///
  /// Attempts JSON parse first; falls back to plain text description.
  VisionResult _parseVisionResponse({
    required String rawContent,
    required int processingTimeMs,
    required String modelUsed,
    Map<String, dynamic>? rawResponse,
  }) {
    // Try to extract JSON from the response (may be wrapped in markdown).
    var jsonStr = rawContent.trim();

    // Strip markdown code fences if present.
    final fenceMatch = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```')
        .firstMatch(jsonStr);
    if (fenceMatch != null) {
      jsonStr = fenceMatch.group(1)?.trim() ?? jsonStr;
    }

    try {
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      final targets = <VisionTarget>[];
      final targetsList = parsed['targets'] as List<dynamic>?;
      if (targetsList != null) {
        for (final t in targetsList) {
          try {
            targets.add(VisionTarget.fromJson(t as Map<String, dynamic>));
          } catch (_) {
            // Skip malformed target entries.
          }
        }
      }

      return VisionResult.fromAnalysis(
        description: parsed['description'] as String? ?? rawContent,
        targets: targets,
        sceneDescription: parsed['scene_description'] as String?,
        ocrText: parsed['ocr_text'] as String?,
        rawResponse: rawResponse,
        processingTimeMs: processingTimeMs,
        modelUsed: modelUsed,
      );
    } catch (_) {
      // JSON parse failed — treat as plain text description.
      return VisionResult.fromAnalysis(
        description: rawContent,
        rawResponse: rawResponse,
        processingTimeMs: processingTimeMs,
        modelUsed: modelUsed,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
  }
}

/// Riverpod provider for the OpenAI Vision service.
///
/// Depends on [aiConnectionStorageProvider] for model, base URL,
/// and API key access — no longer self-provisions FlutterSecureStorage.
final openaiVisionServiceProvider = Provider<OpenAIVisionService>((ref) {
  final connectionStorage = ref.watch(aiConnectionStorageProvider);
  return OpenAIVisionService(connectionStorage: connectionStorage);
});
