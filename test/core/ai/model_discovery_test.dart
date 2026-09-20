/// model_discovery_test.dart
/// AURA Assistant – Phase 1: tests for capability filtering + selection.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/ai/model_discovery.dart';

AIModelInfo _m(
  String id, {
  AIModelCategory category = AIModelCategory.chat,
  bool chat = true,
}) =>
    AIModelInfo(
      id: id,
      rawId: id,
      category: category,
      supportsChat: chat,
    );

void main() {
  group('ModelCapabilityFilter.chatModels', () {
    test('keeps only chat-capable models', () {
      final models = [
        _m('gemini-3.6-flash'),
        _m('text-embedding-004',
            category: AIModelCategory.embedding, chat: false),
        _m('imagen-3.0', category: AIModelCategory.image, chat: false),
        _m('gpt-4o'),
      ];
      final chat = ModelCapabilityFilter.chatModels(models);
      expect(chat.map((e) => e.id),
          containsAll(['gemini-3.6-flash', 'gpt-4o']));
      expect(chat.length, 2);
    });

    test('drops embedding/audio even if mislabeled chat via marker guard', () {
      // supportsChat true + category chat, but id has a non-chat marker.
      final models = [
        _m('some-embedding-model'),
        _m('whisper-large'),
        _m('tts-1'),
        _m('gemini-2.5-flash'),
      ];
      final chat = ModelCapabilityFilter.chatModels(models);
      expect(chat.map((e) => e.id), ['gemini-2.5-flash']);
    });
  });

  group('ModelSelector.select', () {
    test('prefers gemini-3.6-flash by deterministic order', () {
      final models = [
        _m('gemini-1.5-pro'),
        _m('gemini-3.6-flash'),
        _m('gemini-2.0-flash'),
      ];
      final chosen = ModelSelector.select(
        models,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );
      expect(chosen?.id, 'gemini-3.6-flash');
    });

    test('prefers gpt-4o-mini for OpenAI order', () {
      final models = [_m('gpt-4o'), _m('gpt-4o-mini'), _m('gpt-3.5-turbo')];
      final chosen = ModelSelector.select(
        models,
        preferenceOrder: ModelSelector.openAIPreferenceOrder,
      );
      expect(chosen?.id, 'gpt-4o-mini');
    });

    test('excludes the failed model and picks the next best', () {
      final models = [_m('gemini-3.6-flash'), _m('gemini-2.5-flash')];
      final chosen = ModelSelector.select(
        models,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
        exclude: {'gemini-3.6-flash'},
      );
      expect(chosen?.id, 'gemini-2.5-flash');
    });

    test('returns null when no chat models remain', () {
      final models = [
        _m('text-embedding-004',
            category: AIModelCategory.embedding, chat: false),
      ];
      final chosen = ModelSelector.select(
        models,
        preferenceOrder: ModelSelector.geminiPreferenceOrder,
      );
      expect(chosen, isNull);
    });

    test('falls back to alphabetically-smallest when no pattern matches', () {
      final models = [_m('zeta-chat'), _m('alpha-chat')];
      final chosen = ModelSelector.select(
        models,
        preferenceOrder: const ['nomatch'],
      );
      expect(chosen?.id, 'alpha-chat');
    });
  });
}
