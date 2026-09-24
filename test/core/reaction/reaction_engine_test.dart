import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/reaction/reaction.dart';

void main() {
  group('ReactionEngine', () {
    late ReactionCatalog catalog;
    late FrozenClock clock;
    late ReactionHistory history;
    late StyleAwareSelector selector;
    late DeterministicRandomSource random;
    late ReactionEngine engine;
    final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

    setUp(() {
      catalog = ReactionCatalog();
      clock = FrozenClock(baseTime);
      history = ReactionHistory(clock: clock);
      selector = StyleAwareSelector(baseSelector: const ReactionSelector());
      random = DeterministicRandomSource([0.0]); // always pick first
      engine = ReactionEngine(
        catalog: catalog,
        selector: selector,
        history: history,
        randomSource: random,
        clock: clock,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('initial state is idle with no reaction', () {
      expect(engine.state.status, ReactionEngineStatus.idle);
      expect(engine.state.currentReaction, isNull);
      expect(engine.state.totalSelections, 0);
    });

    test('evaluate updates state on matching reaction', () {
      catalog.register(Reaction(
        id: 'test_reaction',
        type: const EmojiReactionType('🧪'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.7,
        requiredVoiceStates: ['listening'],
      ));

      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        voiceState: 'listening',
        timestamp: baseTime,
      );

      engine.evaluate(ctx);

      // evaluate returns void (StateNotifier); check state instead
      expect(engine.state.status, ReactionEngineStatus.reacting);
      expect(engine.state.currentReaction, isNotNull);
      expect(engine.state.currentReaction!.id, 'test_reaction');
      expect(engine.state.lastReactionId, 'test_reaction');
      expect(engine.state.totalSelections, 1);
      expect(engine.state.lastSelectedAt, baseTime);
    });

    test('evaluate records in history', () {
      catalog.register(Reaction(
        id: 'hist_test',
        type: const EmojiReactionType('📝'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      ));

      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        timestamp: baseTime,
      );

      engine.evaluate(ctx);

      expect(history.length, 1);
      expect(history.entries.last.reactionId, 'hist_test');
    });

    test('evaluate no-op when no eligible reaction', () {
      catalog.register(Reaction(
        id: 'wrong_trigger',
        type: const EmojiReactionType('❌'),
        trigger: ReactionTrigger.errorEvent,
        priority: 0.5,
      ));

      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        timestamp: baseTime,
      );

      engine.evaluate(ctx);

      // State should remain idle since no reaction matched
      expect(engine.state.status, ReactionEngineStatus.idle);
      expect(engine.state.currentReaction, isNull);
    });

    test('evaluate no-op when already reacting', () {
      catalog.register(Reaction(
        id: 'first',
        type: const EmojiReactionType('1️⃣'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.9,
      ));
      catalog.register(Reaction(
        id: 'second',
        type: const EmojiReactionType('2️⃣'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      ));

      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        timestamp: baseTime,
      );

      engine.evaluate(ctx);
      expect(engine.state.lastReactionId, 'first');

      // Second evaluate while reacting is a no-op
      engine.evaluate(ctx);
      expect(engine.state.lastReactionId, 'first');
      expect(engine.state.totalSelections, 1); // still 1
    });

    test('transitionBanner completes a reaction cycle', () {
      catalog.register(Reaction(
        id: 'banner_test',
        type: const EmojiReactionType('🎯'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      ));

      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        timestamp: baseTime,
      );

      engine.evaluate(ctx);
      expect(engine.state.status, ReactionEngineStatus.reacting);
      expect(engine.state.currentReaction, isNotNull);

      // Simulate banner lifecycle transitions
      engine.transitionBanner(ReactionBannerLifecycle.entering);
      expect(engine.state.bannerLifecycle, ReactionBannerLifecycle.entering);

      engine.transitionBanner(ReactionBannerLifecycle.visible);
      expect(engine.state.bannerLifecycle, ReactionBannerLifecycle.visible);

      engine.transitionBanner(ReactionBannerLifecycle.exiting);
      expect(engine.state.bannerLifecycle, ReactionBannerLifecycle.exiting);

      // completed triggers reset to idle
      engine.transitionBanner(ReactionBannerLifecycle.completed);
      expect(engine.state.status, ReactionEngineStatus.idle);
      expect(engine.state.currentReaction, isNull);
      expect(engine.state.bannerLifecycle, ReactionBannerLifecycle.idle);
    });

    test('reset clears state', () {
      catalog.register(Reaction(
        id: 'reset_test',
        type: const EmojiReactionType('🔄'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      ));

      final ctx = ReactionContext(
        trigger: ReactionTrigger.voiceState,
        timestamp: baseTime,
      );

      engine.evaluate(ctx);
      expect(engine.state.totalSelections, 1);

      engine.reset();
      expect(engine.state.totalSelections, 0);
      expect(engine.state.lastReactionId, isNull);
      expect(engine.state.status, ReactionEngineStatus.idle);
    });

    test('lifecycleCoordinator is accessible', () {
      expect(engine.lifecycleCoordinator, isNotNull);
    });
  });

  group('ReactionState', () {
    test('initial state is idle', () {
      const state = ReactionState.initial;
      expect(state.status, ReactionEngineStatus.idle);
      expect(state.currentReaction, isNull);
      expect(state.totalSelections, 0);
    });

    test('default constructor is same as initial', () {
      const defaultState = ReactionState();
      expect(defaultState.status, ReactionEngineStatus.idle);
      expect(defaultState.totalSelections, 0);
    });

    test('hasActiveReaction', () {
      const noReaction = ReactionState();
      expect(noReaction.hasActiveReaction, isFalse);

      // hasActiveReaction requires status == reacting AND a currentReaction
      final withReactionButIdle = ReactionState(
        currentReaction: Reaction(
          id: 'active',
          type: const EmojiReactionType('🟢'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.5,
        ),
      );
      expect(withReactionButIdle.hasActiveReaction, isFalse);

      final withReactionAndReacting = ReactionState(
        status: ReactionEngineStatus.reacting,
        currentReaction: Reaction(
          id: 'active',
          type: const EmojiReactionType('🟢'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.5,
        ),
      );
      expect(withReactionAndReacting.hasActiveReaction, isTrue);
    });

    test('copyWith', () {
      const base = ReactionState();
      final updated = base.copyWith(
        status: ReactionEngineStatus.evaluating,
        totalSelections: 5,
      );

      expect(updated.status, ReactionEngineStatus.evaluating);
      expect(updated.totalSelections, 5);
      expect(updated.currentReaction, isNull); // preserved
    });

    test('toString includes useful info', () {
      final state = ReactionState(
        status: ReactionEngineStatus.reacting,
        totalSelections: 3,
      );
      final str = state.toString();
      expect(str, contains('reacting'));
      expect(str, contains('3'));
    });
  });

  group('ReactionEngineStatus', () {
    test('isActive for evaluating and reacting', () {
      expect(ReactionEngineStatus.evaluating.isActive, isTrue);
      expect(ReactionEngineStatus.reacting.isActive, isTrue);
    });

    test('is not active for idle and error', () {
      expect(ReactionEngineStatus.idle.isActive, isFalse);
      expect(ReactionEngineStatus.error.isActive, isFalse);
    });
  });
}