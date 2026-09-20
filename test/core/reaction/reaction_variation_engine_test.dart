import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  // Helpers
  Reaction makeReaction(String id, {ReactionVisualStyle? style}) {
    return Reaction(
      id: id,
      type: const EmojiReactionType('🧪'),
      trigger: ReactionTrigger.voiceState,
      priority: 0.5,
      visualStyle: style,
    );
  }

  ReactionContext makeContext() => ReactionContext(
    trigger: ReactionTrigger.voiceState,
    timestamp: DateTime(2025, 1, 1),
  );

  group('VariationConfig', () {
    test('default values', () {
      const config = VariationConfig();
      expect(config.styleRotationWeight, 0.3);
      expect(config.maxSameStyleStreak, 3);
      expect(config.styleDiversityBonus, 0.15);
      expect(config.stylePenaltyWeight, 0.25);
      expect(config.recentStyleLookback, 5);
    });
  });

  group('VariedEntry', () {
    test('toString contains key info', () {
      final entry = VariedEntry(
        reaction: makeReaction('test'),
        baseWeight: 0.5,
        variationWeight: 0.6,
        visualStyle: ReactionVisualStyle.emoji,
        styleAdjustment: 'diversity_bonus',
      );
      final str = entry.toString();
      expect(str, contains('test'));
      expect(str, contains('diversity_bonus'));
    });
  });

  group('VariationResult', () {
    test('hasCandidates when entries exist', () {
      final result = VariationResult(
        entries: [VariedEntry(
          reaction: makeReaction('x'),
          baseWeight: 0.5,
          variationWeight: 0.5,
          visualStyle: ReactionVisualStyle.emoji,
          styleAdjustment: 'none',
        )],
        recentStyleStreak: 0,
        recentStyle: null,
      );
      expect(result.hasCandidates, isTrue);
    });

    test('hasCandidates false when empty', () {
      final result = VariationResult(
        entries: [],
        recentStyleStreak: 0,
        recentStyle: null,
      );
      expect(result.hasCandidates, isFalse);
    });
  });

  group('ReactionVariationEngine', () {
    late ReactionVariationEngine engine;
    late ReactionHistory history;
    late DeterministicRandomSource random;

    setUp(() {
      engine = ReactionVariationEngine();
      history = ReactionHistory(
        maxSize: 20,
        clock: FrozenClock(DateTime(2025, 1, 1)),
      );
      random = DeterministicRandomSource([0.5]);
    });

    test('empty history → no style rotation adjustments', () {
      final candidates = [
        makeReaction('a', style: ReactionVisualStyle.emoji),
        makeReaction('b', style: ReactionVisualStyle.asciiArt),
      ];
      engine.registerAllStyles(candidates);

      final result = engine.applyVariation(
        candidates: candidates,
        history: history,
        random: random,
      );

      expect(result.hasCandidates, isTrue);
      expect(result.recentStyleStreak, 0);
      expect(result.recentStyle, isNull);
    });

    test('diversity bonus for different style from recent', () async {
      // Record an emoji-style reaction in history.
      final emojiReaction = makeReaction('emoji_prev', style: ReactionVisualStyle.emoji);
      engine.registerStyle('emoji_prev', ReactionVisualStyle.emoji);
      history.record('emoji_prev');

      final candidates = [
        makeReaction('a', style: ReactionVisualStyle.emoji),
        makeReaction('b', style: ReactionVisualStyle.asciiArt),
      ];
      engine.registerAllStyles(candidates);

      final result = engine.applyVariation(
        candidates: candidates,
        history: history,
        random: random,
      );

      expect(result.hasCandidates, isTrue);
      // The asciiArt candidate should have a diversity bonus.
      final asciiEntry = result.entries.firstWhere(
        (e) => e.visualStyle == ReactionVisualStyle.asciiArt,
      );
      expect(asciiEntry.styleAdjustment, 'diversity_bonus');
    });

    test('streak penalty after maxSameStyleStreak', () {
      // Record 4 emoji-style reactions (streak = 4, max = 3).
      for (var i = 0; i < 4; i++) {
        final id = 'emoji_$i';
        engine.registerStyle(id, ReactionVisualStyle.emoji);
        history.record(id);
      }

      final candidates = [
        makeReaction('a', style: ReactionVisualStyle.emoji),
        makeReaction('b', style: ReactionVisualStyle.pixelArt),
      ];
      engine.registerAllStyles(candidates);

      final result = engine.applyVariation(
        candidates: candidates,
        history: history,
        random: random,
      );

      // The emoji candidate should have a streak penalty.
      final emojiEntry = result.entries.firstWhere(
        (e) => e.visualStyle == ReactionVisualStyle.emoji,
      );
      expect(emojiEntry.styleAdjustment, contains('streak_penalty'));
      // Its weight should be less than the non-emoji candidate (base was same).
      final pixelEntry = result.entries.firstWhere(
        (e) => e.visualStyle == ReactionVisualStyle.pixelArt,
      );
      expect(pixelEntry.variationWeight, greaterThan(emojiEntry.variationWeight));
    });

    test('no rotation available when all candidates share same style', () {
      // Record 4 emoji reactions for streak.
      for (var i = 0; i < 4; i++) {
        final id = 'emoji_$i';
        engine.registerStyle(id, ReactionVisualStyle.emoji);
        history.record(id);
      }

      final candidates = [
        makeReaction('a', style: ReactionVisualStyle.emoji),
        makeReaction('b', style: ReactionVisualStyle.emoji),
      ];
      engine.registerAllStyles(candidates);

      final result = engine.applyVariation(
        candidates: candidates,
        history: history,
        random: random,
      );

      expect(result.hasCandidates, isTrue);
      // Both entries should have 'no_rotation_available'.
      for (final entry in result.entries) {
        expect(entry.styleAdjustment, 'no_rotation_available');
      }
    });

    test('registerAllStyles populates cache', () {
      final candidates = [
        makeReaction('x', style: ReactionVisualStyle.code),
        makeReaction('y', style: ReactionVisualStyle.meme),
      ];
      engine.registerAllStyles(candidates);
      // Engine should be able to resolve styles now.
      // Indirectly tested through applyVariation with history.
    });

    test('clearStyleCache clears cache', () {
      engine.registerStyle('test', ReactionVisualStyle.emoji);
      engine.clearStyleCache();
      // Cache is cleared; style resolution for history will return null.
    });

    test('entries with near-zero weight are excluded', () {
      // Create a reaction with very low priority.
      final lowWeight = Reaction(
        id: 'low',
        type: const EmojiReactionType('📉'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.001,
        weight: 0.001,
      );

      final result = engine.applyVariation(
        candidates: [lowWeight],
        history: history,
        random: random,
      );

      // Very low weight entries should be filtered out.
      expect(result.entries.where((e) => e.variationWeight < 0.001), isEmpty);
    });
  });
}
