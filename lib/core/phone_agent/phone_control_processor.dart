/// Phone-control entry point.
///
/// [tryHandle] is installed as [phoneControlHook] and is called from
/// AgentEngine.run() for every screen. [run] only delegates to [inner]
/// (the hook already ran inside it), so nothing is classified twice.
library;

import 'package:flutter/services.dart';

import '../../domain/entities/agent_config.dart';
import '../../domain/services/ai_service.dart';
import '../../services/ai/ai_provider.dart';
import '../ai/ai_message.dart';
import '../agent/agent_context.dart';
import '../agent/agent_result.dart';
import '../live_mode/agent_processor.dart';
import 'phone_agent.dart';

class PhoneControlProcessor implements AgentProcessor {
  PhoneControlProcessor({
    required this.providerGetter,
    this.inner,
  });

  final AIProvider Function() providerGetter;
  final AgentProcessor? inner;

  String _modelId = 'default';

  static const MethodChannel _sys =
      MethodChannel('com.texo.texo/system_control');

  late final PhoneAgent _agent = PhoneAgent(
    llm: _llm,
    askConsent: _consent,
    log: (l) => _toast(l),
  );

  // Cheap pre-filter so ordinary chat never pays for a classifier call.
  static final RegExp _hint = RegExp(
    r'(بکەرەوە|بکەوە|بکەنەوە|هەڵکە|هەڵبکە|دابنێ|دایبنێ|بدۆزەوە|بگەڕێ|بچۆ|بنێرە|بنووسە|'
    r'دایبگرە|بگۆڕە|بکوژێنەوە|ئەلارم|ئەلەرم|ئەپ|یوتوب|فەیسبووک|ئینستاگرام|تیکتۆک|'
    r'واتسئەپ|تێلێگرام|سناپ|گۆرانی|وای ?فای|بلوتوس|open|launch|play|search|go to|'
    r'alarm|turn on|turn off|send|call|youtube|facebook|instagram|whatsapp)',
    caseSensitive: false,
  );

  @override
  Future<AgentResult> run({
    required String userInput,
    required AgentContext context,
  }) async {
    final i = inner;
    if (i == null) {
      return const AgentResult.failure(errorMessage: 'no inner processor');
    }
    return i.run(userInput: userInput, context: context);
  }

  Future<AgentResult?> tryHandle(String userInput, AgentContext context) async {
    if (!_hint.hasMatch(userInput)) return null;
    _modelId = context.agentConfig.modelId;

    if (_agent.isRunning) {
      return const AgentResult.success(
        response: 'هێشتا خەریکی کارەکەی پێشووم.',
      );
    }
    if (!_isPhoneTaskLocal(userInput)) return null;

    final fast = await _tryFast(userInput);
    if (fast != null) return AgentResult.success(response: fast);

    _toast('TEXO: agent starting');
    final r = await _agent.run(userInput);
    _toast('TEXO: agent finished: ${r.message}');
    return AgentResult.success(response: r.killed ? 'وەستێنرا.' : r.message);
  }

  static final RegExp _questionLike = RegExp(
    r'(^|\s)(چی|چۆن|بۆچی|کێ|کەی|لەکوێ|what|how|why|who|when|where)(\s|$)|[؟?]\s*$',
    caseSensitive: false,
  );

  /// Local PHONE/CHAT decision: no LLM call (saves one request per command).
  bool _isPhoneTaskLocal(String text) {
    final isPhone = !_questionLike.hasMatch(text.trim());
    _toast('TEXO: local classifier -> ${isPhone ? 'PHONE' : 'CHAT'}');
    return isPhone;
  }

  static const MethodChannel _dev = MethodChannel('com.texo.texo/device');

  static final RegExp _musicWords = RegExp(
    r'(گۆرانی|گۆرانییەک|موزیک|میوزیک|مۆزیک|مۆسیقا|یوتوب|یوتیوب|youtube|play)',
    caseSensitive: false,
  );
  static const Set<String> _fillers = {
    'لە', 'یوتوب', 'یوتیوب', 'youtube', 'play', 'گۆرانییەک', 'گۆرانی',
    'موزیک', 'میوزیک', 'مۆزیک', 'مۆسیقا', 'بکەوە', 'بکەرەوە', 'بکەنەوە',
    'لێبدە', 'دابنێ', 'بدۆزەوە', 'بگەڕێ', 'بۆم', 'تکایە', 'ئەپی', 'ئەپ',
  };
  static const Set<String> _openWords = {'بکەرەوە', 'بکەنەوە', 'بکەوە'};
  static const Map<String, String> _appNames = {
    'یوتوب': 'youtube', 'یوتیوب': 'youtube', 'فەیسبووک': 'facebook',
    'ئینستاگرام': 'instagram', 'تیکتۆک': 'tiktok', 'واتسئەپ': 'whatsapp',
    'تێلێگرام': 'telegram', 'سناپ': 'snapchat',
  };

  Future<Map<String, dynamic>> _fastCall(
      MethodChannel ch, String m, Map<String, dynamic> a) async {
    try {
      final r = await ch.invokeMethod<dynamic>(m, a);
      if (r is Map) return Map<String, dynamic>.from(r);
      return {'ok': true};
    } on PlatformException catch (e) {
      return {'ok': false, 'error': '${e.code}'};
    } on MissingPluginException {
      return {'ok': false, 'error': 'missing'};
    }
  }

  /// Direct Android intents, no LLM and no screen reading.
  /// Returns a reply text on success, null to fall back to the agent.
  Future<String?> _tryFast(String text) async {
    final t = text.trim();
    final tokens = t.split(RegExp(r'\s+'));
    final hasYoutube = tokens.any((w) {
      final l = w.toLowerCase();
      return l == 'یوتوب' || l == 'یوتیوب' || l == 'youtube';
    });

    if (_musicWords.hasMatch(t)) {
      final q = tokens.where((w) => !_fillers.contains(w.toLowerCase())).join(' ').trim();
      if (q.isEmpty && hasYoutube) {
        final r = await _fastCall(_dev, 'launchApp', {'packageId': 'youtube'});
        return (r['ok'] != false && r['error'] == null) ? 'یوتوبم کردەوە.' : null;
      }
      if (!hasYoutube) {
        await _fastCall(_sys, 'agentBegin', {});
        final r = await _fastCall(_sys, 'a11yStartIntent', {
          'action': 'android.media.action.MEDIA_PLAY_FROM_SEARCH',
          'extras': {
            'query': q,
            'android.intent.extra.focus': 'vnd.android.cursor.item/*',
          },
        });
        await _fastCall(_sys, 'agentEnd', {});
        if (r['ok'] != false) {
          return q.isEmpty ? 'موزیکم دەست پێکرد.' : 'گۆرانی $q دەست پێکرد.';
        }
      }
      if (q.isNotEmpty) {
        final url = 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}';
        final r = await _fastCall(_dev, 'launchUrl', {'url': url});
        if (r['ok'] != false && r['error'] == null) {
          return 'لە یوتوب گەڕام بۆ $q.';
        }
      }
      return null;
    }

    if (tokens.length >= 2 && _openWords.contains(tokens.last)) {
      final name = tokens
          .sublist(0, tokens.length - 1)
          .where((w) => w != 'ئەپی' && w != 'ئەپ')
          .join('')
          .toLowerCase();
      final pkg = _appNames[name];
      if (pkg != null) {
        final r = await _fastCall(_dev, 'launchApp', {'packageId': pkg});
        if (r['ok'] != false && r['error'] == null) return 'کردمەوە.';
      }
    }
    return null;
  }

  Future<bool> _isPhoneTask(String text) async {
    try {
      final out = await _llm(
        'Reply with exactly one word: PHONE or CHAT.',
        'Decide if the user message asks to operate the phone itself '
        '(open an app, play something in an app, search inside an app, set an '
        'alarm, change a setting, navigate to a page, send a message, call '
        'someone, etc.) or is just conversation / a general question.\n\n'
        'Message: $text',
      );
      final isPhone = out.toUpperCase().contains('PHONE');
      _toast('TEXO: classifier -> ${isPhone ? 'PHONE' : 'CHAT'}');
      return isPhone;
    } catch (e) {
      _toast('TEXO: classifier error: $e');
      return false;
    }
  }

  Future<String> _llm(String system, String user) async {
    final cfg = AgentConfig(
      id: 'phone_agent',
      name: 'Phone Agent',
      description: 'Phone control agent',
      systemPrompt: system,
      modelId: _modelId,
      temperature: 0.2,
      maxTokens: 2048,
    );
    final res = await providerGetter().complete(
      AIRequest(
        prompt: user,
        agentConfig: cfg,
        messages: [
          AIMessage.fromMap({'role': 'user', 'content': user}),
        ],
        temperature: 0.2,
        maxTokens: 2048,
      ),
    );
    return res.text;
  }

  Future<bool> _consent(String reason) async {
    try {
      final r = await _sys.invokeMethod<dynamic>('agentAsk', {'message': reason});
      return r is Map && r['allowed'] == true;
    } catch (_) {
      return false;
    }
  }

  void _toast(String m) {
    final msg = m.length > 140 ? m.substring(0, 140) : m;
    _sys
        .invokeMethod<dynamic>('agentToast', {'message': msg})
        .catchError((_) {});
  }
}
