/// voice_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// VoiceTool — handles voice/speech interactions.
/// Category: voice
/// Risk: low (TTS) / medium (STT with recording)
/// Offline: partial (TTS offline, STT may need network)
/// Voice-safe: yes (primary voice interaction)
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class VoiceTool extends Tool {
  @override
  String get id => 'aura.tool.voice';

  @override
  String get name => 'Voice Interaction';

  @override
  ToolCategory get category => ToolCategory.voice;

  @override
  String get description =>
      'Text-to-speech, speech recognition, voice commands';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => [
        'voice.tts',
        'voice.stt',
        'voice.microphone',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.low;

  @override
  bool get requiresConfirmation => false;

  @override
  bool get supportsOffline => true; // TTS offline, STT best-effort

  @override
  bool get isVoiceSafe => true; // Primary voice interaction tool

  @override
  int get defaultTimeoutMs => 10000;

  bool _isExecuting = false;

  @override
  bool get isExecuting => _isExecuting;

  @override
  Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async {
    _isExecuting = true;
    try {
      context.throwIfCancelled();
      if (!input.isValid) {
        return ToolOutput.failure(
            toolId: id,
            errorMessage: 'Invalid voice input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'tts';
      final text = input.sanitizedParams['text'] as String? ?? '';
      final lang = input.sanitizedParams['lang'] as String? ?? context.locale;

      switch (action) {
        case 'tts':
          return ToolOutput.success(toolId: id, data: {
            'action': 'tts',
            'text': text,
            'lang': lang,
            'toolId': id,
          });
        case 'stt':
          return ToolOutput.success(toolId: id, data: {
            'action': 'stt',
            'status': 'listening',
            'lang': lang,
            'toolId': id,
          });
        case 'command':
          return ToolOutput.success(toolId: id, data: {
            'action': 'command',
            'recognized': text,
            'toolId': id,
          });
        default:
          return ToolOutput.failure(
              toolId: id,
            errorMessage: 'Unknown voice action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
          toolId: id,
            errorMessage: 'Voice error');
    } finally {
      _isExecuting = false;
    }
  }

  @override
  ToolInput validate(Map<String, dynamic> params) {
    final action = params['action'] as String?;
    if (action == null || !_validActions.contains(action)) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'action',
        message: 'Valid actions: ${_validActions.join(", ")}',
      );
    }
    if (action == 'tts' && (params['text'] as String?)?.isEmpty != false) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'text',
        message: 'Text is required for TTS',
      );
    }
    return ToolInput.valid(
      toolId: id,
      params: Map<String, dynamic>.from(params),
    );
  }

  @override
  String describe() => 'ئامرازێکی دەنگ بۆ قسەکردنی دەقی و ناسینەوەی دەنگ'; // Kurdish Sorani

  @override
  void cancel() {}

  static const _validActions = ['tts', 'stt', 'command'];
}
