import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('ReactionSelector', () {
    late ReactionCatalog catalog;
    late FrozenClock clock;
    late ReactionHistory history;
    late ReactionSelector selector;
    final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

    setUp(() {
      catalog = ReactionCatalog();
      clock = FrozenClock(baseTime);
      history = ReactionHistory(clock: clock);
      selector = const ReactionSelector();
    });

    group('filtering', () {
      test('selects matching trigger', () {
        catalog.register(Reaction(
          id: 'voice_ear',
          type: const EmojiReactionType('👂'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.7,
          requiredVoiceStates: ['listening'],
        ));

        final ctx = ReactionContext(
          trigger: ReactionTrigger.voiceState,
          voiceState: 'listening',
          timestamp: baseTime,
        );

        // Deterministic: always pick index 0
        final random = DeterministicRandomSource([0.0]);
        final selection = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: random,
        );

        expect(selection.hasReaction, isTrue);
        expect(selection.reaction!.id, 'voice_ear');
      });

      test('filters out mismatched voice state', () {
        catalog.register(Reaction(
          id: 'listening_only',
          type: const EmojiReactionType('👂'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.7,
          requiredVoiceStates: ['listening'],
        ));

        final ctx = ReactionContext(
          trigger: ReactionTrigger.voiceState,
          voiceState: 'speaking',
          timestamp: baseTime,
        );

        final random = DeterministicRandomSource([0.0]);
        final selection = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: random,
        );

        expect(selection.hasReaction, isFalse);
      });

      test('filters out mismatched agent state', () {
        catalog.register(Reaction(
          id: 'executing_only',
          type: const EmojiReactionType('⚙️'),
          trigger: ReactionTrigger.agentState,
          priority: 0.7,
          requiredAgentStates: ['executing'],
        ));

        final ctx = ReactionContext(
          trigger: ReactionTrigger.agentState,
          agentState: 'idle',
          timestamp: baseTime,
        );

        final random = DeterministicRandomSource([0.0]);
        final selection = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: random,
        );

        expect(selection.hasReaction, isFalse);
      });

      test('filters out mismatched intent type', () {
        catalog.register(Reaction(
          id: 'action_only',
          type: const TextReactionType(),
          trigger: ReactionTrigger.agentIntent,
          priority: 0.7,
          requiredIntentTypes: ['action'],
        ));

        final ctx = ReactionContext(
          trigger: ReactionTrigger.agentIntent,
          intentActionType: 'query',
          timestamp: baseTime,
        );

        final random = DeterministicRandomSource([0.0]);
        final selection = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: random,
        );

        expect(selection.hasReaction, isFalse);
      });

      test('filters by minimum confidence', () {
        catalog.register(Reaction(
          id: 'high_conf',
          type: const TextReactionType(),
          trigger: ReactionTrigger.agentIntent,
          priority: 0.7,
          requiredConfidenceMin: 0.8,
        ));

        // Too low confidence
        final ctx1 = ReactionContext(
          trigger: ReactionTrigger.agentIntent,
          intentActionType: 'query',
          intentConfidence: 0.3,
          timestamp: baseTime,
        );
        final random1 = DeterministicRandomSource([0.0]);
        expect(
          selector
              .select(catalog: catalog, context: ctx1, history: history, random: random1)
              .hasReaction,
          isFalse,
        );

        // Sufficient confidence
        final ctx2 = ReactionContext(
          trigger: ReactionTrigger.agentIntent,
          intentActionType: 'query',
          intentConfidence: 0.9,
          timestamp: baseTime,
        );
        final random2 = DeterministicRandomSource([0.0]);
        expect(
          selector
              .select(catalog: catalog, context: ctx2, history: history, random: random2)
              .hasReaction,
          isTrue,
        );
      });

      test('empty requirements match any state', () {
        catalog.register(Reaction(
          id: 'any_state',
          type: const EmojiReactionType('🔄'),
          trigger: ReactionTrigger.agentState,
          priority: 0.5,
        ));

        // No requiredAgentStates, requiredVoiceStates, requiredIntentTypes
        for (final state in ['idle', 'executing', 'completed', 'failed']) {
          final ctx = ReactionContext(
            trigger: ReactionTrigger.agentState,
            agentState: state,
            timestamp: baseTime,
          );
          final random = DeterministicRandomSource([0.0]);
          final selection = selector.select(
            catalog: catalog,
            context: ctx,
            history: history,
            random: random,
          );
          expect(selection.hasReaction, isTrue);
        }
      });
    });

    group('anti-repetition', () {
      test('reduces weight for recently fired reactions', () {
        catalog.register(Reaction(
          id: 'repeated',
          type: const EmojiReactionType('🔁'),
          trigger: ReactionTrigger.voiceState,
          priority: 1.0,
          weight: 1.0,
          cooldown: const Duration(seconds: 60),
        ));
        catalog.register(Reaction(
          id: 'fresh',
          type: const EmojiReactionType('🆕'),
          trigger: ReactionTrigger.voiceState,
          priority: 1.0,
          weight: 1.0,
          cooldown: const Duration(seconds: 60),
        ));

        // Fire 'repeated' once in history
        history.record('repeated');

        final ctx = ReactionContext(
          trigger: ReactionTrigger.voiceState,
          voiceState: 'listening',
          timestamp: baseTime,
        );

        // With deterministic random=0 (picks first entry), the 'repeated'
        // reaction has lower weight due to anti-repetition, so if we
        // roll very low, we might get 'fresh' first.
        // Let's verify by checking many iterations that 'fresh' is picked more.
        var freshCount = 0;
        var repeatedCount = 0;
        final prodRandom = DefaultRandomSource(42);

        for (var i = 0; i < 100; i++) {
          final selection = selector.select(
            catalog: catalog,
            context: ctx,
            history: history,
            random: prodRandom,
          );
          if (selection.reaction!.id == 'fresh') {
            freshCount++;
          } else {
            repeatedCount++;
          }
        }

        // Fresh should be selected more often due to anti-repetition penalty
        expect(freshCount, greaterThan(repeatedCount));
      });

      test('cooldown penalty significantly reduces weight', () {
        catalog.register(Reaction(
          id: 'cooldown_test',
          type: const EmojiReactionType('⏳'),
          trigger: ReactionTrigger.voiceState,
          priority: 1.0,
          weight: 1.0,
          cooldown: const Duration(seconds: 60),
        ));
        catalog.register(Reaction(
          id: 'alternative',
          type: const EmojiReactionType('🔄'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.3, // lower base priority
          weight: 1.0,
          cooldown: const Duration(seconds: 5),
        ));

        // Fire 'cooldown_test' very recently (within 60s cooldown)
        history.record('cooldown_test');

        final ctx = ReactionContext(
          trigger: ReactionTrigger.voiceState,
          voiceState: 'listening',
          timestamp: baseTime,
        );

        // Run many selections — alternative should win most despite lower base priority
        var altWins = 0;
        final prodRandom = DefaultRandomSource(99);

        for (var i = 0; i < 100; i++) {
          final selection = selector.select(
            catalog: catalog,
            context: ctx,
            history: history,
            random: prodRandom,
          );
          if (selection.reaction!.id == 'alternative') {
            altWins++;
          }
        }

        expect(altWins, greaterThan(50));
      });
    });

    group('weighted selection', () {
      test('higher priority reaction selected more often', () {
        catalog.register(Reaction(
          id: 'high_pri',
          type: const EmojiReactionType('⬆️'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.9,
        ));
        catalog.register(Reaction(
          id: 'low_pri',
          type: const EmojiReactionType('⬇️'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.1,
        ));

        final ctx = ReactionContext(
          trigger: ReactionTrigger.voiceState,
          timestamp: baseTime,
        );

        var highCount = 0;
        final prodRandom = DefaultRandomSource(42);

        for (var i = 0; i < 200; i++) {
          final selection = selector.select(
            catalog: catalog,
            context: ctx,
            history: history,
            random: prodRandom,
          );
          if (selection.reaction!.id == 'high_pri') {
            highCount++;
          }
        }

        // high_pri (0.9) should be selected ~90% of the time
        expect(highCount, greaterThan(140));
      });

      test('deterministic random produces reproducible results', () {
        catalog.register(Reaction(
          id: 'a',
          type: const EmojiReactionType('🅰️'),
          trigger: ReactionTrigger.agentState,
          priority: 0.5,
        ));
        catalog.register(Reaction(
          id: 'b',
          type: const EmojiReactionType('🅱️'),
          trigger: ReactionTrigger.agentState,
          priority: 0.5,
        ));

        final ctx = ReactionContext(
          trigger: ReactionTrigger.agentState,
          timestamp: baseTime,
        );

        // With deterministic values [0.0], always picks first entry
        final det = DeterministicRandomSource([0.0]);
        final s1 = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: det,
        );
        final s2 = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: det,
        );

        expect(s1.reaction!.id, s2.reaction!.id);
      });
    });

    group('edge cases', () {
      test('no reactions in catalog returns none', () {
        final ctx = ReactionContext(
          trigger: ReactionTrigger.voiceState,
          timestamp: baseTime,
        );

        final selection = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: DeterministicRandomSource([0.5]),
        );

        expect(selection.hasReaction, isFalse);
        expect(selection, ReactionSelection.none);
      });

      test('no matching trigger returns none', () {
        catalog.register(Reaction(
          id: 'voice_only',
          type: const EmojiReactionType('🎤'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.5,
        ));

        final ctx = ReactionContext(
          trigger: ReactionTrigger.agentState, // different trigger
          timestamp: baseTime,
        );

        final selection = selector.select(
          catalog: catalog,
          context: ctx,
          history: history,
          random: DeterministicRandomSource([0.5]),
        );

        expect(selection.hasReaction, isFalse);
      });

      test('ReactionSelection.none has no reaction', () {
        expect(ReactionSelection.none.hasReaction, isFalse);
        expect(ReactionSelection.none.reaction, isNull);
      });

      test('ReactionSelection.selected wraps reaction', () {
        final r = Reaction(
          id: 'test',
          type: const EmojiReactionType('✅'),
          trigger: ReactionTrigger.wakeEvent,
          priority: 1.0,
        );
        final sel = ReactionSelection.selected(r);
        expect(sel.hasReaction, isTrue);
        expect(sel.reaction!.id, 'test');
      });
    });
  });
}
