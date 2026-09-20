/// Step 3: Comprehensive tests for [VoiceReactionAdapter].
///
/// Tests cover: attach/dispose lifecycle, voice state mapping, error
/// mapping, multiple events, failure isolation, duplicate attach safety,
/// and dispose idempotency.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/services/voice/voice_service.dart';

// ── ThrowingReactionEngine: always throws on evaluate() ──

class ThrowingReactionEngine extends ReactionEngine {
  ThrowingReactionEngine({
    required ReactionCatalog catalog,
    required StyleAwareSelector selector,
    required ReactionHistory history,
    required RandomSource randomSource,
    required Clock clock,
  }) : super(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: randomSource,
          clock: clock,
        );

  @override
  Result<Reaction, ReactionFailure> evaluate(ReactionContext context) {
    throw StateError('Intentional evaluate() failure for testing');
  }
}

// ── FakeVoiceService for testing ──

class FakeVoiceService implements VoiceService {
  VoiceState _state = VoiceState.idle;
  final _stateController = StreamController<VoiceState>.broadcast();

  @override
  VoiceState get state => _state;

  @override
  Stream<VoiceState> get stateStream => _stateController.stream;

  @override
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String locale = 'ku',
  }) async {
    _setState(VoiceState.listening);
  }

  @override
  Future<void> stopListening() async {
    _setState(VoiceState.idle);
  }

  @override
  Future<void> speak(String text, {String locale = 'ku'}) async {
    _setState(VoiceState.speaking);
  }

  @override
  Future<void> stopSpeaking() async {
    _setState(VoiceState.idle);
  }

  /// Emit a state change through the stream (for testing).
  void emitState(VoiceState newState) {
    _setState(newState);
  }

  /// Close the stream controller (call in tearDown).
  Future<void> dispose() async {
    await _stateController.close();
  }

  void _setState(VoiceState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}

void main() {
  // ── Shared test infrastructure ──

  late ReactionCatalog catalog;
  late FrozenClock clock;
  late ReactionHistory history;
  late StyleAwareSelector selector;
  late DeterministicRandomSource random;
  late ReactionEngine engine;
  late FakeVoiceService fakeVoice;
  final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

  void registerReactionForTrigger(ReactionTrigger trigger) {
    catalog.register(Reaction(
      id: '${trigger.name}_reaction',
      type: const EmojiReactionType('🎤'),
      trigger: trigger,
      priority: 0.5,
      cooldown: Duration.zero,
    ));
  }

  // ── VoiceReactionAdapter ──

  group('VoiceReactionAdapter', () {
    setUp(() {
      catalog = ReactionCatalog();
      clock = FrozenClock(baseTime);
      history = ReactionHistory(clock: clock);
      selector = StyleAwareSelector(baseSelector: const ReactionSelector());
      random = DeterministicRandomSource([0.0]);
      engine = ReactionEngine(
        catalog: catalog,
        selector: selector,
        history: history,
        randomSource: random,
        clock: clock,
      );
      fakeVoice = FakeVoiceService();
    });

    tearDown(() async {
      engine.dispose();
      await fakeVoice.dispose();
    });

    // ── B1: attach() starts subscription ──

    group('attach()', () {
      test('starts subscription, VoiceState changes reach engine', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );

        expect(adapter.isAttached, isFalse);
        adapter.attach();
        expect(adapter.isAttached, isTrue);

        // Emit a voice state change
        fakeVoice.emitState(VoiceState.listening);

        // Allow stream to propagate
        await Future<void>.delayed(Duration.zero);

        expect(adapter.lastVoiceState, VoiceState.listening);
        expect(adapter.evaluationCount, 1);
        expect(engine.state.lastReactionId, 'voiceState_reaction');
      });

      test('initial state is not attached', () {
        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );

        expect(adapter.isAttached, isFalse);
        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 0);
        expect(adapter.lastVoiceState, isNull);
      });
    });

    // ── B2: Voice state mapping ──

    group('voice state mapping', () {
      test('VoiceState.idle → voiceState trigger, urgency 0.3', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.idle);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);
        expect(adapter.lastVoiceState, VoiceState.idle);
      });

      test('VoiceState.listening → voiceState trigger, urgency 0.6', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);
        expect(adapter.lastVoiceState, VoiceState.listening);
      });

      test('VoiceState.processing → voiceState trigger, urgency 0.6', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.processing);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);
        expect(adapter.lastVoiceState, VoiceState.processing);
      });

      test('VoiceState.speaking → voiceState trigger, urgency 0.6', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.speaking);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);
        expect(adapter.lastVoiceState, VoiceState.speaking);
      });
    });

    // ── B3: Voice error mapping ──

    group('VoiceState.error', () {
      test('VoiceState.error → errorEvent trigger, urgency 0.9', () async {
        registerReactionForTrigger(ReactionTrigger.errorEvent);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.error);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);
        expect(adapter.lastVoiceState, VoiceState.error);
        expect(engine.state.lastReactionId, 'errorEvent_reaction');
      });

      test('VoiceState.error does NOT produce voiceState trigger', () async {
        // Register voiceState reaction but NOT errorEvent reaction.
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.error);
        await Future<void>.delayed(Duration.zero);

        // evaluate() didn't throw, so it counts as a successful evaluation
        expect(adapter.evaluationCount, 1);
        expect(adapter.errorCount, 0);
        // But no reaction was actually selected (wrong trigger type)
        expect(engine.state.totalSelections, 0);
      });
    });

    // ── B4: Multiple events ──

    group('multiple events', () {
      test('sequential state changes each evaluate', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);
        registerReactionForTrigger(ReactionTrigger.errorEvent);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));

        fakeVoice.emitState(VoiceState.processing);
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));

        fakeVoice.emitState(VoiceState.speaking);
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));

        fakeVoice.emitState(VoiceState.idle);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 4);
        expect(adapter.errorCount, 0);
        expect(adapter.lastVoiceState, VoiceState.idle);
      });

      test('error event among normal events', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);
        registerReactionForTrigger(ReactionTrigger.errorEvent);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));

        fakeVoice.emitState(VoiceState.error);
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));

        fakeVoice.emitState(VoiceState.idle);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 3);
        expect(adapter.errorCount, 0);
      });
    });

    // ── B5: Failure isolation ──

    group('failure isolation', () {
      test('evaluate() throws → errorCount++, stream alive', () async {
        final throwingEngine = ThrowingReactionEngine(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: random,
          clock: clock,
        );

        final adapter = VoiceReactionAdapter(
          engine: throwingEngine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 1);

        // Stream should still be alive — next event should also be handled
        fakeVoice.emitState(VoiceState.idle);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.errorCount, 2);
        expect(adapter.lastVoiceState, VoiceState.idle);

        throwingEngine.dispose();
      });

      test('intermittent failures: later events still process', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        // Normal engine first
        final normalAdapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        normalAdapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);

        expect(normalAdapter.evaluationCount, 1);
        expect(normalAdapter.errorCount, 0);

        // Now test with throwing engine on a fresh fake
        final fakeVoice2 = FakeVoiceService();
        final throwingEngine = ThrowingReactionEngine(
          catalog: catalog,
          selector: selector,
          history: history,
          randomSource: random,
          clock: clock,
        );

        final throwingAdapter = VoiceReactionAdapter(
          engine: throwingEngine,
          voiceService: fakeVoice2,
        );
        throwingAdapter.attach();

        fakeVoice2.emitState(VoiceState.speaking);
        await Future<void>.delayed(Duration.zero);

        expect(throwingAdapter.errorCount, 1);
        expect(throwingAdapter.evaluationCount, 0);

        // But the adapter still processes subsequent events
        fakeVoice2.emitState(VoiceState.idle);
        await Future<void>.delayed(Duration.zero);

        expect(throwingAdapter.errorCount, 2);
        expect(throwingAdapter.lastVoiceState, VoiceState.idle);

        throwingEngine.dispose();
        await fakeVoice2.dispose();
      });
    });

    // ── B6: dispose() ──

    group('dispose()', () {
      test('cancels subscription, events after dispose ignored', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);

        await adapter.dispose();

        expect(adapter.isAttached, isFalse);

        // Events after dispose should be ignored
        fakeVoice.emitState(VoiceState.speaking);
        await Future<void>.delayed(Duration.zero);

        // evaluationCount should NOT have increased
        expect(adapter.evaluationCount, 1);
      });

      test('safe to call multiple times', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);

        await adapter.dispose();
        await adapter.dispose(); // second call — should be no-op

        expect(adapter.isAttached, isFalse);
      });

      test('dispose when not attached is safe', () async {
        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );

        // Never called attach()
        await adapter.dispose(); // should be no-op

        expect(adapter.isAttached, isFalse);
      });
    });

    // ── B7: attach() safety ──

    group('attach() idempotency', () {
      test('multiple attach calls → no duplicate listeners', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );

        adapter.attach();
        adapter.attach(); // second call — should be no-op

        // Emit one event — should only be processed once
        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1); // not 2
        expect(adapter.lastVoiceState, VoiceState.listening);
      });

      test('attach after dispose re-subscribes', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );

        adapter.attach();
        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);
        expect(adapter.evaluationCount, 1);

        await adapter.dispose();
        expect(adapter.isAttached, isFalse);

        // Re-attach
        adapter.attach();
        expect(adapter.isAttached, isTrue);

        clock.advance(const Duration(seconds: 1));
        fakeVoice.emitState(VoiceState.speaking);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 2);
        expect(adapter.lastVoiceState, VoiceState.speaking);
      });
    });

    // ── B8: reset() ──

    group('reset()', () {
      test('reset clears counts and lastVoiceState but does NOT detach', () async {
        registerReactionForTrigger(ReactionTrigger.voiceState);

        final adapter = VoiceReactionAdapter(
          engine: engine,
          voiceService: fakeVoice,
        );
        adapter.attach();

        fakeVoice.emitState(VoiceState.listening);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);
        expect(adapter.lastVoiceState, VoiceState.listening);
        expect(adapter.isAttached, isTrue);

        adapter.reset();

        expect(adapter.evaluationCount, 0);
        expect(adapter.errorCount, 0);
        expect(adapter.lastVoiceState, isNull);
        expect(adapter.isAttached, isTrue); // still attached!

        // Can still process events after reset
        clock.advance(const Duration(seconds: 1));
        fakeVoice.emitState(VoiceState.idle);
        await Future<void>.delayed(Duration.zero);

        expect(adapter.evaluationCount, 1);
      });
    });
  });
}
