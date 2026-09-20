/// agent_processor_test.dart
/// AURA P0 – Unit tests for AgentProcessor abstract interface
///
/// Verifies: interface contract, AgentResult construction,
/// AgentContext usage, interface compliance.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/live_mode/agent_processor.dart';
import 'package:aura_assistant/core/agent/agent_result.dart';
import 'package:aura_assistant/core/agent/agent_context.dart';
import 'package:aura_assistant/domain/entities/agent_config.dart';

void main() {
  group('AgentProcessor interface', () {
    test('AgentResult.success holds response and isSuccess', () {
      final result = const AgentResult.success(
        response: 'بەخێربێیت',
        stepsCompleted: 1,
      );
      expect(result.response, 'بەخێربێیت');
      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
    });
    
    test('AgentResult.failure holds errorMessage and !isSuccess', () {
      final result = const AgentResult.failure(
        errorMessage: 'هەڵەیەک ڕوویدا',
      );
      expect(result.response, isNull);
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'هەڵەیەک ڕوویدا');
    });
    
    test('AgentContext requires agentConfig', () {
      final config = const AgentConfig(
        id: 'test',
        name: 'تاقیکردنەوە',
        description: 'test agent',
        systemPrompt: 'تۆ یاریدەدەری',
        modelId: 'gpt-4o-mini',
        temperature: 0.5,
        maxTokens: 1024,
        isDefault: false,
        isActive: true,
      );
      final context = AgentContext(
        agentConfig: config,
        conversationHistory: [],
        maxSteps: 5,
      );
      expect(context.agentConfig.id, 'test');
      expect(context.maxSteps, 5);
    });
    
    test('concrete AgentProcessor implementation works', () async {
      final fake = _FakeAgentProcessor();
      final config = const AgentConfig(
        id: 'test',
        name: 'تاقیکردنەوە',
        description: 'test',
        systemPrompt: 'تۆ یاریدەدەری',
        modelId: 'gpt-4o-mini',
        temperature: 0.5,
        maxTokens: 1024,
        isDefault: false,
        isActive: true,
      );
      final context = AgentContext(
        agentConfig: config,
        conversationHistory: [],
      );
      
      final result = await fake.run(userInput: 'سڵاو', context: context);
      expect(result.isSuccess, isTrue);
      expect(result.response, 'وەڵام');
    });
  });
}

class _FakeAgentProcessor implements AgentProcessor {
  @override
  Future<AgentResult> run({
    required String userInput,
    required AgentContext context,
  }) async {
    return const AgentResult.success(response: 'وەڵام', stepsCompleted: 1);
  }
}
