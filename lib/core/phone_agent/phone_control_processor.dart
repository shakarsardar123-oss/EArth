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
    if (!await _isPhoneTask(userInput)) return null;

    _toast('TEXO: agent starting');
    final r = await _agent.run(userInput);
    _toast('TEXO: agent finished: ${r.message}');
    return AgentResult.success(response: r.killed ? 'وەستێنرا.' : r.message);
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
