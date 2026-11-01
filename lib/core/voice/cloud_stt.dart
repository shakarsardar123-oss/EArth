/// cloud_stt.dart
/// Fast Sorani speech-to-text through the Gemini API, using the SAME provider
/// (key, base URL and model) the app already uses for chat. Returns null on any
/// failure so the caller can fall back to the on-device Vekol model.
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

  static const Duration _timeout = Duration(seconds: 8);

  /// Set by the app: returns the Gemini provider the app itself uses (or null).
  GeminiProvider? Function()? resolver;

  late final GeminiProvider _standalone =
      GeminiProvider(secureStorage: const FlutterSecureStorage());

  /// Last result, for diagnostics ("ok", "http 404", "no key", ...).
  String lastStatus = 'not used yet';

  String? _key;
  DateTime _keyCheckedAt = DateTime.fromMillisecondsSinceEpoch(0);

  GeminiProvider _provider() => resolver?.call() ?? _standalone;

  /// True when an API key is stored (re-checked at most every 20 s).
  Future<bool> available() async {
    final DateTime now = DateTime.now();
    if (_key == null || now.difference(_keyCheckedAt).inSeconds > 20) {
      try {
        _key = (await _provider().getApiKey())?.trim();
        if ((_key ?? '').isEmpty && resolver != null) {
          _key = (await _standalone.getApiKey())?.trim();
        }
      } catch (_) {
        _key = null;
      }
      _keyCheckedAt = now;
    }
    final bool ok = _key != null && _key!.isNotEmpty;
    if (!ok) lastStatus = 'no key';
    return ok;
  }

  static const String _prompt =
      'You are a speech-to-text engine for Central Kurdish (Sorani). '
      'Transcribe the audio EXACTLY as spoken, in Kurdish Arabic script with '
      'standard Sorani spelling (ە ێ ۆ ڵ ڕ ڤ). The speaker gives voice commands and '
      'questions to a phone assistant called TEXO (تێکسۆ). Product and app names '
      'are often said in English or Arabic; write them in Kurdish script: '
      'TikTok = تیکتۆک, YouTube = یوتیوب, Facebook = فەیسبووک, Instagram = ئینستاگرام, '
      'Snapchat = سناپچات, WhatsApp = واتسئاپ, Telegram = تێلێگرام, Google = گووگڵ, '
      'Chrome = کرۆم, Settings = ڕێکخستنەکان, Clash of Clans = کلاش ئۆف کلانس, '
      'Spotify = سپۆتیفای. Frequent commands: بکەرەوە, بدۆزەوە, بخوێنەرەوە, '
      'سێرچ بکە, بنووسە, ڕاکە, هەڵسە, بخەوە, بێدەنگ بە. '
      'Output ONLY the transcription: no quotes, no translation, no notes. '
      'If there is no intelligible speech, output nothing.';

  String _model(GeminiProvider p) {
    String m = '';
    try {
      m = (p.connectionStorage?.getModel() ?? '').toString();
    } catch (_) {}
    m = m
        .replaceFirst(RegExp(r'^models/'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return m.isEmpty ? kDefaultGeminiChatModel : m;
  }

  Future<http.Response> _post(GeminiProvider p, String model, String wav) async {
    final String baseUrl = await p.getBaseUrl();
    final Uri uri = GeminiProvider.buildGenerateContentUri(
      baseUrl: baseUrl,
      model: model,
      apiKey: _key!,
    );
    final Map<String, Object?> body = <String, Object?>{
      'contents': <Object?>[
        <String, Object?>{
          'role': 'user',
          'parts': <Object?>[
            <String, Object?>{'text': _prompt},
            <String, Object?>{
              'inline_data': <String, Object?>{'mime_type': 'audio/wav', 'data': wav},
            },
          ],
        },
      ],
      'generationConfig': <String, Object?>{'temperature': 0, 'maxOutputTokens': 384},
    };
    return http
        .post(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  /// Transcribes a base64 WAV (16 kHz, mono). Returns the text ('' when there
  /// was no speech) or null when the cloud could not be used.
  Future<String?> transcribe(String wavBase64) async {
    try {
      if (!await available()) return null;
      final GeminiProvider p = _provider();
      String model = _model(p);
      http.Response r = await _post(p, model, wavBase64);
      if ((r.statusCode == 404 || r.statusCode == 400) && model != kDefaultGeminiChatModel) {
        model = kDefaultGeminiChatModel;
        r = await _post(p, model, wavBase64);
      }
      if (r.statusCode != 200) {
        lastStatus = 'http ${r.statusCode} ($model)';
        return null;
      }
      final Object? decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is! Map) return null;
      final Object? cands = decoded['candidates'];
      lastStatus = 'ok ($model)';
      if (cands is! List || cands.isEmpty) return '';
      final Object? content = (cands.first as Map)['content'];
      if (content is! Map) return '';
      final Object? parts = content['parts'];
      if (parts is! List) return '';
      final StringBuffer out = StringBuffer();
      for (final Object? part in parts) {
        if (part is Map && part['text'] is String) out.write(part['text']);
      }
      return out
          .toString()
          .trim()
          .replaceAll(RegExp('^["\u201C\u201D]+|["\u201C\u201D]+\$'), '')
          .trim();
    } catch (e) {
      lastStatus = 'error: $e';
      return null;
    }
  }
}
