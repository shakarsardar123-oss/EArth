import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';

/// Plays a song / video on YouTube by itself: it looks the query up on YouTube,
/// takes the first video and opens it directly (no screen tapping, so no
/// confirmation dialogs). If the video cannot be found it opens the search
/// results instead and says so in the result.
class YoutubePlayTool extends Tool {
  YoutubePlayTool();

  static const MethodChannel _device = MethodChannel('com.texo.texo/device');

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'youtube_play',
        description:
            'لە یوتیوب بگەڕێ و یەکەم ڤیدیۆ/گۆرانی دەرکەوتوو ڕاستەوخۆ پەخش بکە. '
            '— '
            'Search YouTube for the query and play the first matching video '
            'directly. Use this when the user asks to play a song or video on '
            'YouTube (query = song title and artist). Do it yourself; never '
            'tell the user to search manually.',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'query',
            type: 'string',
            description:
                'ناوی گۆرانی و هونەرمەند یان ناوی ڤیدیۆ. '
                '— '
                'Song title and artist, or the video title.',
            isRequired: true,
            example: 'Awat Bokani',
            label: 'گەڕان',
            hintText: 'Awat Bokani',
            keyboardType: 'text',
          ),
        ],
        permissionRequirements: [],
        isDangerous: false,
        requiresConfirmation: false,
        tags: [
          'youtube',
          'play',
          'music',
          'video',
          'song',
          'یوتیوب',
          'گۆرانی',
          'پەخش',
        ],
        icon: 'play_circle',
        timeout: Duration(seconds: 25),
        riskLevel: ToolRiskLevel.low,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final String? q = arguments.getString('query');
    if (q == null || q.trim().isEmpty) {
      return 'query is required. — گەڕان پێویستە.';
    }
    if (q.length > 200) {
      return 'query is too long. — گەڕان زۆر درێژە.';
    }
    return null;
  }

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    final String? err = validateArguments(arguments);
    if (err != null) {
      return ToolResult.failure(err, errorCode: 'invalidArguments');
    }
    final String query = arguments.getString('query')!.trim();

    String? id;
    try {
      id = await _firstVideoId(query);
    } catch (_) {
      id = null;
    }

    final String url = id != null
        ? 'https://www.youtube.com/watch?v=$id'
        : 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(query)}';
    try {
      await _device.invokeMethod<Object?>('launchUrl', <String, Object?>{'url': url});
    } catch (e) {
      return ToolResult.failure('Could not open YouTube: $e', errorCode: 'launchFailed');
    }

    return ToolResult.success(<String, dynamic>{
      'query': query,
      'playing': id != null,
      'videoId': id,
      'note': id != null
          ? 'The first matching video was opened in YouTube and is playing.'
          : 'The video could not be picked automatically; the YouTube search '
              'results for the query were opened instead.',
    });
  }

  /// Reads the YouTube results page and returns the id of the first video.
  static Future<String?> _firstVideoId(String query) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final Uri uri = Uri.https(
        'www.youtube.com',
        '/results',
        <String, String>{'search_query': query},
      );
      final HttpClientRequest req = await client.getUrl(uri);
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0 Mobile Safari/537.36',
      );
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      req.cookies.add(Cookie('CONSENT', 'YES+1'));
      final HttpClientResponse res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final String body = await res
          .transform(const Utf8Decoder(allowMalformed: true))
          .join()
          .timeout(const Duration(seconds: 12));
      final RegExpMatch? m =
          RegExp(r'"videoRenderer":\{"videoId":"([A-Za-z0-9_-]{11})"').firstMatch(body) ??
              RegExp(r'"videoId":"([A-Za-z0-9_-]{11})"').firstMatch(body);
      return m?.group(1);
    } finally {
      client.close(force: true);
    }
  }
}
