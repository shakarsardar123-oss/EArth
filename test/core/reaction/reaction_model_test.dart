import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('Reaction', () {
    test('creates with required fields', () {
      final reaction = Reaction(
        id: 'test',
        type: const EmojiReactionType('🧪'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );

      expect(reaction.id, 'test');
      expect(reaction.type, const EmojiReactionType('🧪'));
      expect(reaction.trigger, ReactionTrigger.voiceState);
      expect(reaction.priority, 0.5);
      expect(reaction.weight, 1.0); // default
      expect(reaction.cooldown, const Duration(seconds: 30)); // default
    });

    test('effectivePriority includes weight and urgency', () {
      final reaction = Reaction(
        id: 'weighted',
        type: const EmojiReactionType('⚖️'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        weight: 2.0,
        urgency: ReactionUrgency.high,
      );

      // effectivePriority = priority × urgency.value = 0.5 × 0.75
      expect(reaction.effectivePriority, closeTo(0.375, 0.001));
    });

    test('effectivePriority for low urgency', () {
      final reaction = Reaction(
        id: 'low',
        type: const EmojiReactionType('📉'),
        trigger: ReactionTrigger.idleTimeout,
        priority: 0.8,
        urgency: ReactionUrgency.low,
      );

      // effectivePriority = 0.8 × 0.25
      expect(reaction.effectivePriority, closeTo(0.2, 0.001));
    });

    test('copyWith preserves unchanged fields', () {
      final base = Reaction(
        id: 'base',
        type: const EmojiReactionType('📋'),
        trigger: ReactionTrigger.agentState,
        priority: 0.8,
        urgency: ReactionUrgency.high,
      );

      final copied = base.copyWith(priority: 0.3);

      expect(copied.id, 'base');
      expect(copied.type, const EmojiReactionType('📋'));
      expect(copied.trigger, ReactionTrigger.agentState);
      expect(copied.priority, 0.3);
      expect(copied.urgency, ReactionUrgency.high);
    });

    test('copyWith can override specific fields', () {
      final base = Reaction(
        id: 'base',
        type: const EmojiReactionType('📋'),
        trigger: ReactionTrigger.agentState,
        priority: 0.8,
      );

      final copied = base.copyWith(
        id: 'new_id',
        trigger: ReactionTrigger.errorEvent,
        urgency: ReactionUrgency.critical,
      );

      expect(copied.id, 'new_id');
      expect(copied.trigger, ReactionTrigger.errorEvent);
      expect(copied.urgency, ReactionUrgency.critical);
      expect(copied.priority, 0.8); // unchanged
    });

    test('equality based on checked fields', () {
      final a = Reaction(
        id: 'eq',
        type: const EmojiReactionType('✅'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );
      final b = Reaction(
        id: 'eq',
        type: const EmojiReactionType('✅'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality with different id', () {
      final a = Reaction(
        id: 'a',
        type: const EmojiReactionType('❌'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );
      final b = Reaction(
        id: 'b',
        type: const EmojiReactionType('❌'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );

      expect(a, isNot(b));
    });

    test('default urgency is normal', () {
      final reaction = Reaction(
        id: 'urg',
        type: const EmojiReactionType('⚡'),
        trigger: ReactionTrigger.errorEvent,
        priority: 0.5,
      );

      expect(reaction.urgency, ReactionUrgency.normal);
    });

    test('default tone is neutral', () {
      final reaction = Reaction(
        id: 'tone',
        type: const HumorReactionType(),
        trigger: ReactionTrigger.idleTimeout,
        priority: 0.5,
      );

      expect(reaction.tone, ReactionTone.neutral);
    });

    test('requiredVoiceStates defaults to empty', () {
      final reaction = Reaction(
        id: 'noVoice',
        type: const EmojiReactionType('🔇'),
        trigger: ReactionTrigger.agentState,
        priority: 0.5,
      );

      expect(reaction.requiredVoiceStates, isEmpty);
    });

    test('requiredAgentStates with values', () {
      final reaction = Reaction(
        id: 'agentReq',
        type: const EmojiReactionType('🤖'),
        trigger: ReactionTrigger.agentState,
        priority: 0.5,
        requiredAgentStates: ['executing', 'planning'],
      );

      expect(reaction.requiredAgentStates, ['executing', 'planning']);
    });

    test('requiredIntentTypes with values', () {
      final reaction = Reaction(
        id: 'intentReq',
        type: const CodeReactionType('dart'),
        trigger: ReactionTrigger.agentIntent,
        priority: 0.5,
        requiredIntentTypes: ['action', 'create'],
      );

      expect(reaction.requiredIntentTypes, ['action', 'create']);
    });

    test('requiredConfidenceMin default is null', () {
      final reaction = Reaction(
        id: 'conf',
        type: const EmojiReactionType('🎯'),
        trigger: ReactionTrigger.agentIntent,
        priority: 0.5,
      );

      expect(reaction.requiredConfidenceMin, isNull);
    });

    test('requiredConfidenceMin with value', () {
      final reaction = Reaction(
        id: 'confVal',
        type: const EmojiReactionType('🎯'),
        trigger: ReactionTrigger.agentIntent,
        priority: 0.5,
        requiredConfidenceMin: 0.7,
      );

      expect(reaction.requiredConfidenceMin, 0.7);
    });

    test('payload with map', () {
      final reaction = Reaction(
        id: 'payload',
        type: const NativeOverlayReactionType(),
        trigger: ReactionTrigger.toolExecution,
        priority: 0.5,
        payload: {'color': '#FF0000', 'duration': 500},
      );

      expect(reaction.payload, {'color': '#FF0000', 'duration': 500});
    });

    test('category and tags', () {
      final reaction = Reaction(
        id: 'cat',
        type: const EmojiReactionType('🏷️'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        category: 'voice',
        tags: ['feedback', 'confirmation'],
      );

      expect(reaction.category, 'voice');
      expect(reaction.tags, ['feedback', 'confirmation']);
    });

    test('isNativeRenderable delegates to type', () {
      final emojiReaction = Reaction(
        id: 'native',
        type: const EmojiReactionType('✨'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );
      expect(emojiReaction.isNativeRenderable, isTrue);

      final humorReaction = Reaction(
        id: 'not_native',
        type: const HumorReactionType(),
        trigger: ReactionTrigger.idleTimeout,
        priority: 0.5,
      );
      expect(humorReaction.isNativeRenderable, isFalse);
    });

    test('toString includes id, trigger, type, priority', () {
      final reaction = Reaction(
        id: 'str',
        type: const EmojiReactionType('🔥'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.8,
      );

      final str = reaction.toString();
      expect(str, contains('str'));
      expect(str, contains('voiceState'));
      expect(str, contains('0.8'));
    });

    // Step 4: visualStyle field tests
    test('visualStyle defaults to null', () {
      final reaction = Reaction(
        id: 'vs',
        type: const EmojiReactionType('🎨'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );
      expect(reaction.visualStyle, isNull);
    });

    test('visualStyle can be set explicitly', () {
      final reaction = Reaction(
        id: 'vs',
        type: const EmojiReactionType('🎨'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.pixelArt,
      );
      expect(reaction.visualStyle, ReactionVisualStyle.pixelArt);
    });

    test('copyWith preserves visualStyle', () {
      final base = Reaction(
        id: 'vs',
        type: const EmojiReactionType('🎨'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.code,
      );
      final copied = base.copyWith(priority: 0.9);
      expect(copied.visualStyle, ReactionVisualStyle.code);
    });

    test('copyWith can change visualStyle', () {
      final base = Reaction(
        id: 'vs',
        type: const EmojiReactionType('🎨'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.emoji,
      );
      final copied = base.copyWith(
        visualStyle: ReactionVisualStyle.meme,
      );
      expect(copied.visualStyle, ReactionVisualStyle.meme);
    });

    test('copyWith can clear visualStyle', () {
      final base = Reaction(
        id: 'vs',
        type: const EmojiReactionType('🎨'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.emoji,
      );
      final copied = base.copyWith(clearVisualStyle: true);
      expect(copied.visualStyle, isNull);
    });

    test('equality includes visualStyle', () {
      final a = Reaction(
        id: 'eq',
        type: const EmojiReactionType('✅'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.pixelArt,
      );
      final b = Reaction(
        id: 'eq',
        type: const EmojiReactionType('✅'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.pixelArt,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality with different visualStyle', () {
      final a = Reaction(
        id: 'eq',
        type: const EmojiReactionType('✅'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.emoji,
      );
      final b = Reaction(
        id: 'eq',
        type: const EmojiReactionType('✅'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        visualStyle: ReactionVisualStyle.pixelArt,
      );
      expect(a, isNot(b));
    });
  });

  group('ReactionUrgency', () {
    test('has all expected values', () {
      expect(ReactionUrgency.values, containsAll([
        ReactionUrgency.low,
        ReactionUrgency.normal,
        ReactionUrgency.high,
        ReactionUrgency.critical,
      ]));
    });

    test('value doubles are ordered', () {
      expect(ReactionUrgency.low.value, lessThan(ReactionUrgency.normal.value));
      expect(ReactionUrgency.normal.value, lessThan(ReactionUrgency.high.value));
      expect(ReactionUrgency.high.value, lessThan(ReactionUrgency.critical.value));
    });
  });

  group('ReactionTone', () {
    test('has all expected values', () {
      expect(ReactionTone.values, containsAll([
        ReactionTone.neutral,
        ReactionTone.positive,
        ReactionTone.humorous,
        ReactionTone.soothing,
        ReactionTone.technical,
      ]));
    });
  });
}
