import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../ai/endpoint_validator.dart';
import '../../ai/gemini_provider.dart';
import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';

/// Answers questions about current facts (news, weather, prices, sports,
/// "who is ... now") with Gemini + Google Search grounding. This is a separate
/// request (the search tool cannot be mixed with function declarations), so the
/// chat model calls this tool and then speaks the result.
class WebSearchTool extends Tool {
  /// [provider] returns the selected AI provider (read lazily, so a key typed
  /// later in Settings is picked up).
  WebSearchTool(this._provider);

  final dynamic Function() _provider;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'web_search',
        description:
            'گەڕان لە ئینتەرنێت بۆ زانیاریی نوێ: هەواڵ، کەشوهەوا، نرخ، ئەنجامی یاری، و هەر شتێک کە لە ئێستادا گۆڕاوە. '
            '— '
            'Search the web with Google and return a short, current answer. '
            'Use it for news, weather, prices, sports results and anything that '
            'may have changed recently. Never open a browser for such questions; '
            'call this tool and then answer the user yourself.',
        category: 'search',
        parameters: [
          ToolArgumentDef(
            name: 'query',
            type: 'string',
            description:
                'پرسیارەکە بە تەواوی (زمانی ئەوەی بەکارهێنەر گوتی). '
                '— '
                'The full question to look up.',
            isRequired: true,
            example: 'latest news',
            label: 'گەڕان',
            hintText: 'latest news',
            keyboardType: 'text',
          ),
        ],
        permissionRequirements: [],
        isDangerous: false,
        requiresConfirmation: false,
        tags: [
          'search',
          'news',
          'weather',
          'price',
          'web',
          'هەواڵ',
          'گەڕان',
          'کەشوهەوا',
          'نرخ',
        ],
        icon: 'travel_explore',
        timeout: Duration(seconds: 45),
        riskLevel: ToolRiskLevel.low,
      );

  @override
  String? validateArguments(ToolArguments arguments) {
    final String? q = arguments.getString('query');
    if (q == null || q.trim().isEmpty) {
      return 'query is required. — پرسیار پێویستە.';
    }
    if (q.length > 400) {
      return 'query is too long. — پرسیار زۆر درێژە.';
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

    try {
      final dynamic p = _provider();
      final String? apiKey = await p.getApiKey() as String?;
      if (apiKey == null || apiKey.isEmpty) {
        return ToolResult.failure(
          'Gemini API key is not set. — کلیلی Gemini دانەنراوە.',
          errorCode: 'noApiKey',
        );
      }
      final String baseUrl = EndpointValidator.normalizeTrailingSlash(
        (await p.getBaseUrl()) as String,
      );
      final dynamic storage = p.connectionStorage;
      final String model = (storage?.getModel() as String?) ?? kDefaultGeminiChatModel;

      final Uri uri = GeminiProvider.buildGenerateContentUri(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
      );
      final Map<String, dynamic> body = <String, dynamic>{
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{
                'text': 'Search the web and answer in at most six short sentences, '
                    'in Kurdish Sorani, with the most recent facts and dates. '
                    'Question: $query',
              },
            ],
          },
        ],
        'tools': <Map<String, dynamic>>[
          <String, dynamic>{'google_search': <String, dynamic>{}},
        ],
        'generationConfig': <String, dynamic>{
          'temperature': 0.3,
          'maxOutputTokens': 900,
        },
      };

      final http.Response res = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode != 200) {
        String msg = 'HTTP ${res.statusCode}';
        try {
          final dynamic e = jsonDecode(res.body);
          msg = '${e['error']['message']}';
        } catch (_) {}
        return ToolResult.failure('Search failed: $msg', errorCode: 'searchFailed');
      }

      final dynamic data = jsonDecode(res.body);
      final List<dynamic>? cands = data['candidates'] as List<dynamic>?;
      if (cands == null || cands.isEmpty) {
        return ToolResult.failure('The search returned nothing.', errorCode: 'empty');
      }
      final dynamic cand = cands.first;
      final List<dynamic>? parts = cand['content']?['parts'] as List<dynamic>?;
      final StringBuffer text = StringBuffer();
      if (parts != null) {
        for (final dynamic part in parts) {
          final dynamic t = part['text'];
          if (t is String) text.write(t);
        }
      }
      final String answer = text.toString().trim();
      if (answer.isEmpty) {
        return ToolResult.failure('The search returned no text.', errorCode: 'empty');
      }

      final List<String> sources = <String>[];
      final List<dynamic>? chunks = cand['groundingMetadata']?['groundingChunks'] as List<dynamic>?;
      if (chunks != null) {
        for (final dynamic c in chunks) {
          final dynamic title = c['web']?['title'];
          if (title is String && title.isNotEmpty && !sources.contains(title)) {
            sources.add(title);
          }
          if (sources.length >= 3) break;
        }
      }
      return ToolResult.success(<String, dynamic>{
        'query': query,
        'answer': answer,
        'sources': sources,
      });
    } catch (e) {
      return ToolResult.failure('Search error: $e', errorCode: 'internalError');
    }
  }
}
