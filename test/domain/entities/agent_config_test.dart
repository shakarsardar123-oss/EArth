import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/domain/entities/agent_config.dart';

void main() {
  group('AgentConfig', () {
    test('creates with required fields and defaults', () {
      const config = AgentConfig(
        id: 'test',
        name: 'Test Agent',
        description: 'A test agent',
        systemPrompt: 'You are a test agent.',
      );
      expect(config.id, 'test');
      expect(config.name, 'Test Agent');
      expect(config.description, 'A test agent');
      expect(config.systemPrompt, 'You are a test agent.');
      expect(config.modelId, 'default');
      expect(config.temperature, 0.7);
      expect(config.maxTokens, 2048);
      expect(config.isDefault, isFalse);
      expect(config.isActive, isTrue);
      expect(config.avatarUrl, isNull);
      expect(config.createdAt, isNull);
      expect(config.updatedAt, isNull);
    });

    test('creates with all custom fields', () {
      final now = DateTime(2025, 1, 1);
      final config = AgentConfig(
        id: 'custom',
        name: 'Custom',
        description: 'desc',
        systemPrompt: 'prompt',
        modelId: 'gpt-4',
        temperature: 0.5,
        maxTokens: 4096,
        isDefault: true,
        isActive: false,
        avatarUrl: 'https://example.com/avatar.png',
        createdAt: now,
        updatedAt: now,
      );
      expect(config.modelId, 'gpt-4');
      expect(config.temperature, 0.5);
      expect(config.maxTokens, 4096);
      expect(config.isDefault, isTrue);
      expect(config.isActive, isFalse);
      expect(config.avatarUrl, 'https://example.com/avatar.png');
      expect(config.createdAt, now);
    });

    test('copyWith overrides specified fields', () {
      const original = AgentConfig(
        id: 'a1',
        name: 'Original',
        description: 'desc',
        systemPrompt: 'prompt',
      );
      final copied = original.copyWith(
        name: 'Updated',
        temperature: 1.0,
      );
      expect(copied.id, 'a1');
      expect(copied.name, 'Updated');
      expect(copied.description, 'desc');
      expect(copied.temperature, 1.0);
      expect(copied.maxTokens, 2048);
    });

    test('copyWith with no arguments returns identical copy', () {
      const original = AgentConfig(
        id: 'x',
        name: 'Y',
        description: 'd',
        systemPrompt: 'p',
      );
      final copied = original.copyWith();
      expect(copied.id, original.id);
      expect(copied.name, original.name);
      expect(copied.description, original.description);
    });

    test('equality is based on id', () {
      const a = AgentConfig(id: '1', name: 'A', description: 'd', systemPrompt: 'p');
      const b = AgentConfig(id: '1', name: 'B', description: 'd2', systemPrompt: 'p2');
      const c = AgentConfig(id: '2', name: 'A', description: 'd', systemPrompt: 'p');
      expect(a == b, isTrue); // same id
      expect(a == c, isFalse); // different id
    });

    test('hashCode is based on id', () {
      const a = AgentConfig(id: '1', name: 'A', description: 'd', systemPrompt: 'p');
      const b = AgentConfig(id: '1', name: 'B', description: 'd2', systemPrompt: 'p2');
      expect(a.hashCode, b.hashCode);
    });
  });
}
