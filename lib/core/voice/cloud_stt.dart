/// cloud_stt.dart
/// Fast Sorani speech-to-text through the Gemini API (the key the user already
/// entered in Settings). Returns null on any failure so the caller can fall
/// back to the on-device Vekol model.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../ai/gemini_provider.dart'
    show GeminiProvider, kDefaultGeminiChatModel;

class CloudStt {
  CloudStt._();
  static final CloudStt instance = CloudStt._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 7);

  late final GeminiProvider _gemini = GeminiProvider(secureStorage: _storage);

  String? _key;
  DateTime _keyCheckedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// True when an API key is stored (re-checked at most every 30 s).
  Future<bool> available() async {
    final DateTime now = DateTime.now();
    if (_key == null || now.difference(_keyCheckedAt).inSeconds > 30) {
      try {
        _key = (await _gemini.getApiKey())?.trim();
      } catch (_) {
        _key = null;
      }
      _keyCheckedAt = now;
    }
    return _key != null && _key!.isNotEmpty;
  }

  /// Transcribes a base64 WAV (16 kHz, mono).
  ///
  /// Returns the text ('' when no speech was found) or null when the cloud
  /// could not be used (no key, no network, HTTP error, timeout).
  Future<String?> transcribe(String wavBase64) async {
    try {
      if (!await available()) return null;
      final String baseUrl = await _gemini.getBaseUrl();
      final Uri uri = GeminiProvider.buildGenerateContentUri(
        baseUrl: baseUrl,
        model: kDefaultGeminiChatModel,
        apiKey: _key!,
      );
      final Map<String, Object?> body = <String, Object?>{
        'contents': <Object?>[
          <String, Object?>{
            'role': 'user',
            'parts': <Object?>[
              <String, Object?>{
                'text': 'Transcribe this audio exactly as spoken. The language '
                    'is Central Kurdish (Sorani), written in Kurdish Arabic '
                    'script; it may contain a few English or Arabic words. '
                    'Output ONLY the transcription, no quotes and no '
                    'explanation. If there is no intelligible speech, output '
                    'nothing.',
              },
              <String, Object?>{
                'inline_data': <String, Object?>{
                  'mime_type': 'audio/wav',
                  'data': wavBase64,
                },
              },
            ],
          },
        ],
        'generationConfig': <String, Object?>{
          'temperature': 0,
          'maxOutputTokens': 512,
        },
      };
      final http.Response r = await http
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      final Object? decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is! Map) return null;
      final Object? cands = decoded['candidates'];
      if (cands is! List || cands.isEmpty) return '';
      final Object? content = (cands.first as Map)['content'];
      if (content is! Map) return '';
      final Object? parts = content['parts'];
      if (parts is! List) return '';
      final StringBuffer out = StringBuffer();
      for (final Object? part in parts) {
        if (part is Map && part['text'] is String) out.write(part['text']);
      }
      return out.toString().trim().replaceAll(RegExp(r'^["\u201C\u201D]+|["\u201C\u201D]+$'), '').trim();
    } catch (_) {
      return null;
    }
  }
}
