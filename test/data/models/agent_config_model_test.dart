import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/data/models/agent_config_model.dart';
import 'package:aura_assistant/domain/entities/agent_config.dart';

void main() {
  group('AgentConfigModel', () {
    final testDate = DateTime(2025, 6, 15, 10, 30);
    final testDateStr = testDate.toIso8601String();

    final testJson = <String, dynamic>{
      'id': 'agent1',
      'name': 'AURA',
      'description': 'Main assistant',
      'system_prompt': 'You are AURA.',
      'model_id': 'default',
      'temperature': 0.7,
      'max_tokens': 2048,
      'is_default': true,
      'is_active': true,
      'avatar_url': null,
      'created_at': testDateStr,
      'updated_at': null,
    };

    test('fromJson creates correct model', () {
      final model = AgentConfigModel.fromJson(testJson);
      expect(model.id, 'agent1');
      expect(model.name, 'AURA');
      expect(model.description, 'Main assistant');
      expect(model.systemPrompt, 'You are AURA.');
      expect(model.modelId, 'default');
      expect(model.temperature, 0.7);
      expect(model.maxTokens, 2048);
      expect(model.isDefault, isTrue);
      expect(model.isActive, isTrue);
      expect(model.avatarUrl, isNull);
      expect(model.createdAt, testDate);
      expect(model.updatedAt, isNull);
    });

    test('toJson produces correct map with snake_case keys', () {
      final model = AgentConfigModel(
        id: 'agent1',
        name: 'AURA',
        description: 'Main assistant',
        systemPrompt: 'You are AURA.',
        modelId: 'default',
        temperature: 0.7,
        maxTokens: 2048,
        isDefault: true,
        isActive: true,
        avatarUrl: null,
        createdAt: testDate,
        updatedAt: null,
      );
      final json = model.toJson();
      expect(json['id'], 'agent1');
      expect(json['name'], 'AURA');
      expect(json['system_prompt'], 'You are AURA.');
      expect(json['model_id'], 'default');
      expect(json['temperature'], 0.7);
      expect(json['max_tokens'], 2048);
      expect(json['is_default'], isTrue);
      expect(json['is_active'], isTrue);
      expect(json['avatar_url'], isNull);
      expect(json['created_at'], testDateStr);
      expect(json['updated_at'], isNull);
    });

    test('toEntity converts to AgentConfig correctly', () {
      final model = AgentConfigModel.fromJson(testJson);
      final entity = model.toEntity();
      expect(entity, isA<AgentConfig>());
      expect(entity.id, model.id);
      expect(entity.name, model.name);
      expect(entity.description, model.description);
      expect(entity.systemPrompt, model.systemPrompt);
      expect(entity.modelId, model.modelId);
      expect(entity.temperature, model.temperature);
      expect(entity.maxTokens, model.maxTokens);
      expect(entity.isDefault, model.isDefault);
      expect(entity.isActive, model.isActive);
    });

    test('fromEntity creates correct model', () {
      final entity = AgentConfig(
        id: 'x',
        name: 'Test',
        description: 'desc',
        systemPrompt: 'prompt',
        modelId: 'gpt-4',
        temperature: 0.9,
        maxTokens: 1024,
        isDefault: false,
        isActive: false,
        avatarUrl: 'https://example.com/a.png',
        createdAt: testDate,
        updatedAt: testDate,
      );
      final model = AgentConfigModel.fromEntity(entity);
      expect(model.id, 'x');
      expect(model.name, 'Test');
      expect(model.systemPrompt, 'prompt');
      expect(model.modelId, 'gpt-4');
      expect(model.temperature, 0.9);
      expect(model.maxTokens, 1024);
      expect(model.isDefault, isFalse);
      expect(model.isActive, isFalse);
      expect(model.avatarUrl, 'https://example.com/a.png');
    });

    test('round-trip: fromEntity -> toJson preserves data', () {
      const entity = AgentConfig(
        id: 'rt',
        name: 'RoundTrip',
        description: 'd',
        systemPrompt: 'sp',
      );
      final model = AgentConfigModel.fromEntity(entity);
      final json = model.toJson();
      expect(json['id'], 'rt');
      expect(json['name'], 'RoundTrip');
      expect(json['system_prompt'], 'sp');
      expect(json['model_id'], 'default');
      expect(json['temperature'], 0.7);
      expect(json['max_tokens'], 2048);
    });

    test('handles null DateTime fields gracefully', () {
      final json = Map<String, dynamic>.from(testJson);
      json['created_at'] = null;
      json['updated_at'] = null;
      final model = AgentConfigModel.fromJson(json);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
    });

    test('uses defaults for missing optional fields', () {
      final minimalJson = <String, dynamic>{
        'id': 'minimal',
        'name': 'M',
        'description': 'd',
        'system_prompt': 'p',
      };
      final model = AgentConfigModel.fromJson(minimalJson);
      expect(model.modelId, 'default');
      expect(model.temperature, 0.7);
      expect(model.maxTokens, 2048);
      expect(model.isDefault, isFalse);
      expect(model.isActive, isTrue);
    });
  });
}
