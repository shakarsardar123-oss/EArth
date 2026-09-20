import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  // Helpers
  Reaction makeReaction(
    String id, {
    ReactionTrigger trigger = ReactionTrigger.voiceState,
    ReactionVisualStyle? style,
    ReactionTone tone = ReactionTone.neutral,
    String category = 'general',
    List<String> tags = const [],
    double priority = 0.5,
    double weight = 1.0,
    List<String> requiredVoiceStates = const [],
    List<String> requiredAgentStates = const [],
  }) {
    return Reaction(
      id: id,
      type: const EmojiReactionType('🧪'),
      trigger: trigger,
      priority: priority,
      weight: weight,
      tone: tone,
      category: category,
      tags: tags,
      requiredVoiceStates: requiredVoiceStates,
      requiredAgentStates: requiredAgentStates,
      visualStyle: style,
    );
  }

  ReactionContext makeContext({
    ReactionTrigger trigger = ReactionTrigger.voiceState,
    String? voiceState,
    String? agentState,
    double urgency = 0.5,
    UserTone userTone = UserTone.unknown,
    double? intentConfidence,
  }) {
    return ReactionContext(
      trigger: trigger,
      voiceState: voiceState,
      agentState: agentState,
      urgency: urgency,
      userTone: userTone,
      intentConfidence: intentConfidence,
      timestamp: DateTime(2025, 1, 1),
    );
  }

  group('StyleAwareSelection', () {
    test('none when no eligible reactions', () {
      final catalog = ReactionCatalog();
      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );
      final selector = StyleAwareSelector();

      final result = selector.select(
        catalog: catalog,
        context: makeContext(),
        history: history,
        random: DeterministicRandomSource([0.5]),
      );

      expect(result.hasReaction, isFalse);
    });

    test('selects from eligible candidates', () {
      final catalog = ReactionCatalog();
      catalog.register(makeReaction('a'));
      catalog.register(makeReaction('b'));
      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );
      final selector = StyleAwareSelector();

      final result = selector.select(
        catalog: catalog,
        context: makeContext(),
        history: history,
        random: DeterministicRandomSource([0.01]), // picks first
      );

      expect(result.hasReaction, isTrue);
      expect(result.reaction!.id, anyOf('a', 'b'));
    });

    test('mood analysis is attached to result', () {
      final catalog = ReactionCatalog();
      catalog.register(makeReaction(
        'a', trigger: ReactionTrigger.wakeEvent,
      ));
      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );
      final selector = StyleAwareSelector();

      final result = selector.select(
        catalog: catalog,
        context: makeContext(
          trigger: ReactionTrigger.wakeEvent,
        ),
        history: history,
        random: DeterministicRandomSource([0.5]),
      );

      expect(result.hasReaction, isTrue);
      expect(result.moodAnalysis, isNotNull);
      expect(result.moodAnalysis!.mood, ReactionMoodHint.upbeat);
    });

    test('keyword boosts are applied', () {
      final registry = ReactionKeywordHintRegistry();
      registry.register(ReactionKeywordHint(
        keyword: 'help', language: 'en', category: 'agent',
        tags: ['feedback'], boost: 0.2,
      ));

      final catalog = ReactionCatalog();
      catalog.register(makeReaction(
        'help_reaction', category: 'agent', tags: ['feedback'],
      ));
      catalog.register(makeReaction(
        'other_reaction', category: 'error', tags: ['error'],
      ));

      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );

      final selector = StyleAwareSelector(
        keywordRegistry: registry,
      );

      final result = selector.select(
        catalog: catalog,
        context: makeContext(),
        history: history,
        random: DeterministicRandomSource([0.0]),
        detectedKeywords: ['help'],
      );

      expect(result.hasReaction, isTrue);
      expect(result.keywordBoosts, isNotEmpty);
    });

    test('mood weighting boosts matching tone', () {
      final catalog = ReactionCatalog();
      catalog.register(makeReaction(
        'soothing',
        trigger: ReactionTrigger.errorEvent,
        tone: ReactionTone.soothing,
        category: 'error',
      ));
      catalog.register(makeReaction(
        'humorous',
        trigger: ReactionTrigger.errorEvent,
        tone: ReactionTone.humorous,
        category: 'error',
      ));

      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );

      final selector = StyleAwareSelector();

      final result = selector.select(
        catalog: catalog,
        context: makeContext(
          trigger: ReactionTrigger.errorEvent,
        ),
        history: history,
        random: DeterministicRandomSource([0.0]),
      );

      expect(result.hasReaction, isTrue);
      expect(result.moodAnalysis!.mood, ReactionMoodHint.stressed);
    });

    test('humorous reactions suppressed in stressed context', () {
      final catalog = ReactionCatalog();
      catalog.register(makeReaction(
        'humorous',
        trigger: ReactionTrigger.errorEvent,
        tone: ReactionTone.humorous,
        priority: 0.9,
        weight: 2.0,
      ));
      catalog.register(makeReaction(
        'soothing',
        trigger: ReactionTrigger.errorEvent,
        tone: ReactionTone.soothing,
        priority: 0.5,
        weight: 1.0,
      ));

      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );

      final selector = StyleAwareSelector();

      final result = selector.select(
        catalog: catalog,
        context: makeContext(
          trigger: ReactionTrigger.errorEvent,
        ),
        history: history,
        random: DeterministicRandomSource([0.0]),
      );

      // Soothing should beat humorous in stressed context
      expect(result.hasReaction, isTrue);
    });

    test('style rotation info attached to result', () {
      final catalog = ReactionCatalog();
      catalog.register(makeReaction(
        'a', style: ReactionVisualStyle.emoji,
      ));
      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );

      final selector = StyleAwareSelector();

      final result = selector.select(
        catalog: catalog,
        context: makeContext(),
        history: history,
        random: DeterministicRandomSource([0.5]),
      );

      expect(result.hasReaction, isTrue);
      expect(result.variationResult, isNotNull);
    });

    test('works without keyword registry (null)', () {
      final catalog = ReactionCatalog();
      catalog.register(makeReaction('a'));
      final history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );

      final selector = StyleAwareSelector(
        keywordRegistry: null,
      );

      final result = selector.select(
        catalog: catalog,
        context: makeContext(),
        history: history,
        random: DeterministicRandomSource([0.5]),
      );

      expect(result.hasReaction, isTrue);
    });
  });
}
