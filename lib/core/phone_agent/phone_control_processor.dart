/// Decorator around the real [AgentProcessor] (AgentEngine).
///
/// If the user's message is a phone-control task (open apps, play music,
/// alarms, navigate inside apps, ...) it is handed to [PhoneAgent].
/// Everything else goes to [inner] exactly as before.
library;

import 'package:flutter/services.dart';

import '../../domain/entities/agent_config.dart';
import '../../domain/services/ai_service.dart';
import '../../services/ai/ai_provider.dart';
import '../agent/agent_context.dart';
import '../agent/agent_result.dart';
import '../live_mode/agent_processor.dart';
import 'phone_agent.dart';

class PhoneControlProcessor implements AgentProcessor {
  PhoneControlProcessor({
    required this.inner,
    required this.providerGetter,
    this.log,
  });

  final AgentProcessor inner;
  final AIProvider Function() providerGetter;
  final void Function(String line)? log;

  String _modelId = 'default';

  late final PhoneAgent _agent = PhoneAgent(
    llm: _llm,
    askConsent: _consent,
    log: log,
  );

  static const MethodChannel _sys = MethodChannel('com.texo.texo/system_control');

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
    _modelId = context.agentConfig.modelId;

    if (_agent.isRunning || !_hint.hasMatch(userInput) || !await _isPhoneTask(userInput)) {
      return inner.run(userInput: userInput, context: context);
    }

    final r = await _agent.run(userInput);
    return AgentResult.success(
      response: r.killed ? 'وەستێنرا.' : r.message,
    );
  }

  Future<bool> _isPhoneTask(String text) async {
    try {
      final out = await _llm(
        'Reply with exactly one word.',
        'Decide if the user message asks to operate the phone itself '
        '(open an app, play something in an app, search inside an app, set an alarm, '
        'change a setting, navigate to a page, send a message, call someone, etc.) '
        'or is just conversation / a general question.\n'
        'Reply PHONE or CHAT only.\n\nMessage: $text',
      );
      return out.toUpperCase().contains('PHONE');
    } catch (_) {
      return false; // classifier failure -> normal chat path
    }
  }

  Future<String> _llm(String system, String user) async {
    final cfg = AgentConfig(
      id: 'phone_agent',
      name: 'Phone Agent',
      description: 'Phone control agent',
      systemPrompt: 'Reply with JSON or the single word asked for. No prose.',
      modelId: _modelId,
      temperature: 0.2,
      maxTokens: 1024,
    );
    final res = await providerGetter().complete(
      AIRequest(
        prompt: '$system\n\n---\n$user',
        agentConfig: cfg,
        temperature: 0.2,
        maxTokens: 1024,
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
}
