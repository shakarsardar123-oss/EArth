// voice_first_execution_test.dart — Structural tests for VoiceFirstExecution
// Uses registry.byCategory(), registry.allTools, registry.get()
// Structural validation only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/tool_execution/application/voice_first_execution.dart';
import 'package:aura_assistant/features/tool_execution/infrastructure/executors/tool_executor_registry.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_output.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_execution_context.dart';
import 'package:aura_assistant/features/tool_execution/domain/services/tool_interface.dart';
import 'package:aura_assistant/features/tool_execution/domain/models/tool_input.dart';

void main() {
  group('VoiceFirstExecution', () {
    test('uses registry.byCategory() for voice tools', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'voice_tool', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'device_tool', riskLevel: 'low'));
      final voice = VoiceFirstExecution(registry: registry);
      final voiceTools = voice.voiceTools;
      // Uses registry.byCategory() internally
      expect(voiceTools, isA<List<Tool>>());
    });

    test('uses registry.allTools for full catalog', () {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'a', riskLevel: 'low'));
      registry.register(_MockTool(toolId: 'b', riskLevel: 'medium'));
      final voice = VoiceFirstExecution(registry: registry);
      expect(voice.allAvailableTools.length, equals(2));
    });

    test('uses registry.get() for specific tool', () async {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'voice_tool', riskLevel: 'low'));
      final voice = VoiceFirstExecution(registry: registry);
      final tool = voice.getTool('voice_tool');
      expect(tool, isNotNull);
      expect(tool!.toolId, equals('voice_tool'));
    });

    test('voice-first execution returns ToolOutput', () async {
      final registry = ToolExecutorRegistry();
      registry.register(_MockTool(toolId: 'voice_tool', riskLevel: 'low'));
      final voice = VoiceFirstExecution(registry: registry);
      final result = await voice.execute(
        toolId: 'voice_tool',
        params: {'text': 'Hello'},
        context: ToolExecutionContext(),
      );
      expect(result, isA<ToolOutput>());
    });

    test('FAIL-CLOSED: unregistered voice tool denied', () async {
      final registry = ToolExecutorRegistry();
      final voice = VoiceFirstExecution(registry: registry);
      final result = await voice.execute(
        toolId: 'nonexistent_voice',
        params: {},
        context: ToolExecutionContext(),
      );
      expect(
        result.status == ToolOutputStatus.denied ||
        result.status == ToolOutputStatus.failClosed,
        isTrue,
      );
    });

    test('default locale is ku (Kurdini Sorani RTL)', () {
      final context = ToolExecutionContext();
      expect(context.locale, equals('ku'));
    });
  });
}

class _MockTool extends Tool {
  final String _toolId;
  final String _riskLevel;
  _MockTool({required String toolId, required String riskLevel})
      : _toolId = toolId, _riskLevel = riskLevel;
  @override String get toolId => _toolId;
  @override String get riskLevel => _riskLevel;
  @override ToolInput validate(Map<String, dynamic> params) =>
      ToolInput.valid(toolId: _toolId, params: params);
  @override Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async =>
      ToolOutput.success(toolId: _toolId, data: {});
  @override bool cancel() => true;
}
