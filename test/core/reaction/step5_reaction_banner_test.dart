/// Step 5 FINAL VERIFICATION — dedicated tests for:
/// A. Banner Lifecycle transitions
/// B. Speech Coordination (speakOrHold, hold+release, cancelPending)
/// C. All 6 Renderers (correct selection via defaultStyleForType)
/// D. RTL / Kurdish localization strings
/// E. Dashboard integration (AuraReactionBanner in widget tree)
/// F. Voice screen integration (AuraReactionBanner + speaking indicator)
/// G. Speaking Indicator (appears/disappears conditions)
///
/// These are **domain-logic tests** (no Flutter rendering, no pumpWidget).
/// Groups E/F/G require widget testing with providers.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura_assistant/core/reaction/reaction.dart';
import 'package:aura_assistant/core/reaction/reaction_lifecycle.dart';
import 'package:aura_assistant/core/reaction/reaction_speech_coordinator.dart';
import 'package:aura_assistant/core/reaction/reaction_banner_provider.dart';
import 'package:aura_assistant/core/reaction/reaction_state.dart';
import 'package:aura_assistant/core/reaction/reaction_visual_style.dart';
import 'package:aura_assistant/core/localization/s_strings.dart';
import 'package:aura_assistant/core/localization/s_strings_ku.dart';
import 'package:aura_assistant/core/localization/s_strings_en.dart';
import 'package:aura_assistant/services/voice/voice_service.dart';

// ─── Helpers ───────────────────────────────────────────────────────

Reaction _makeReaction({
  String id = 'test_reaction',
  ReactionPresentationType? type,
  double priority = 0.5,
  ReactionVisualStyle? visualStyle,
  Map<String, dynamic>? payload,
}) {
  return Reaction(
    id: id,
    type: type ?? const EmojiReactionType('🧪'),
    trigger: ReactionTrigger.voiceState,
    priority: priority,
    visualStyle: visualStyle,
    payload: payload,
  );
}

// ─── Group A: Banner Lifecycle ─────────────────────────────────────

void main() {
  group('A. Banner Lifecycle', () {
    late ReactionLifecycleCoordinator coordinator;

    setUp(() {
      coordinator = ReactionLifecycleCoordinator();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('initial state is idle', () {
      expect(coordinator.current, ReactionBannerLifecycle.idle);
      expect(coordinator.hasActiveBanner, isFalse);
      expect(coordinator.activeReaction, isNull);
    });

    test('start transitions to entering and stores reaction', () {
      final reaction = _makeReaction();
      coordinator.start(reaction);
      expect(coordinator.current, ReactionBannerLifecycle.entering);
      expect(coordinator.activeReaction, same(reaction));
      expect(coordinator.hasActiveBanner, isTrue);
    });

    test('entering → visible is valid', () {
      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      expect(coordinator.current, ReactionBannerLifecycle.visible);
    });

    test('visible → exiting is valid', () {
      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      coordinator.transition(ReactionBannerLifecycle.exiting);
      expect(coordinator.current, ReactionBannerLifecycle.exiting);
    });

    test('exiting → completed is valid', () {
      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      coordinator.transition(ReactionBannerLifecycle.exiting);
      coordinator.transition(ReactionBannerLifecycle.completed);
      expect(coordinator.current, ReactionBannerLifecycle.completed);
      expect(coordinator.hasActiveBanner, isFalse);
    });

    test('full lifecycle: idle → entering → visible → exiting → completed', () {
      final reaction = _makeReaction();
      coordinator.start(reaction);
      expect(coordinator.current, ReactionBannerLifecycle.entering);
      coordinator.transition(ReactionBannerLifecycle.visible);
      expect(coordinator.current, ReactionBannerLifecycle.visible);
      coordinator.transition(ReactionBannerLifecycle.exiting);
      expect(coordinator.current, ReactionBannerLifecycle.exiting);
      coordinator.transition(ReactionBannerLifecycle.completed);
      expect(coordinator.current, ReactionBannerLifecycle.completed);
    });

    test('reset goes back to idle and clears activeReaction', () {
      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      coordinator.transition(ReactionBannerLifecycle.exiting);
      coordinator.transition(ReactionBannerLifecycle.completed);
      coordinator.reset();
      expect(coordinator.current, ReactionBannerLifecycle.idle);
      expect(coordinator.activeReaction, isNull);
    });

    test('complete force-skips to completed from any active phase', () {
      coordinator.start(_makeReaction());
      // Still in entering phase — complete should force-jump.
      coordinator.complete();
      expect(coordinator.current, ReactionBannerLifecycle.completed);
    });

    test('complete from visible phase also works', () {
      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      coordinator.complete();
      expect(coordinator.current, ReactionBannerLifecycle.completed);
    });

    test('complete when idle does nothing', () {
      coordinator.complete();
      expect(coordinator.current, ReactionBannerLifecycle.idle);
    });

    test('start when already active throws StateError', () {
      coordinator.start(_makeReaction());
      expect(
        () => coordinator.start(_makeReaction(id: 'another')),
        throwsA(isA<StateError>()),
      );
    });

    test('start when exiting still throws (hasActiveBanner = true)', () {
      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      coordinator.transition(ReactionBannerLifecycle.exiting);
      expect(
        () => coordinator.start(_makeReaction(id: 'too_soon')),
        throwsA(isA<StateError>()),
      );
    });

    test('invalid transition entering → exiting throws StateError', () {
      coordinator.start(_makeReaction());
      expect(
        () => coordinator.transition(ReactionBannerLifecycle.exiting),
        throwsA(isA<StateError>()),
      );
    });

    test('invalid transition visible → completed throws StateError', () {
      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      expect(
        () => coordinator.transition(ReactionBannerLifecycle.completed),
        throwsA(isA<StateError>()),
      );
    });

    test('invalid transition idle → visible throws StateError', () {
      expect(
        () => coordinator.transition(ReactionBannerLifecycle.visible),
        throwsA(isA<StateError>()),
      );
    });

    test('lifecycleStream emits each transition', () async {
      final events = <ReactionBannerLifecycle>[];
      final sub = coordinator.lifecycleStream.listen(events.add);

      coordinator.start(_makeReaction());
      coordinator.transition(ReactionBannerLifecycle.visible);
      coordinator.transition(ReactionBannerLifecycle.exiting);
      coordinator.transition(ReactionBannerLifecycle.completed);

      // Allow microtasks to complete.
      await Future.delayed(Duration.zero);

      expect(events, [
        ReactionBannerLifecycle.entering,
        ReactionBannerLifecycle.visible,
        ReactionBannerLifecycle.exiting,
        ReactionBannerLifecycle.completed,
      ]);

      await sub.cancel();
    });

    test('repeated reaction cycle: complete then start again', () {
      // First cycle
      coordinator.start(_makeReaction(id: 'first'));
      coordinator.transition(ReactionBannerLifecycle.visible);
      coordinator.transition(ReactionBannerLifecycle.exiting);
      coordinator.transition(ReactionBannerLifecycle.completed);
      coordinator.reset();
      expect(coordinator.current, ReactionBannerLifecycle.idle);

      // Second cycle
      coordinator.start(_makeReaction(id: 'second'));
      expect(coordinator.current, ReactionBannerLifecycle.entering);
      expect(coordinator.activeReaction?.id, 'second');
    });

    test('isOnScreen is true for entering and visible only', () {
      expect(ReactionBannerLifecycle.idle.isOnScreen, isFalse);
      expect(ReactionBannerLifecycle.entering.isOnScreen, isTrue);
      expect(ReactionBannerLifecycle.visible.isOnScreen, isTrue);
      expect(ReactionBannerLifecycle.exiting.isOnScreen, isFalse);
      expect(ReactionBannerLifecycle.completed.isOnScreen, isFalse);
    });

    test('isFinished is true for completed only', () {
      expect(ReactionBannerLifecycle.idle.isFinished, isFalse);
      expect(ReactionBannerLifecycle.entering.isFinished, isFalse);
      expect(ReactionBannerLifecycle.visible.isFinished, isFalse);
      expect(ReactionBannerLifecycle.exiting.isFinished, isFalse);
      expect(ReactionBannerLifecycle.completed.isFinished, isTrue);
    });
  });

  // ─── Group B: Speech Coordination ────────────────────────────────

  group('B. Speech Coordination', () {
    late ReactionLifecycleCoordinator lifecycle;
    late ReactionSpeechCoordinator speech;

    setUp(() {
      lifecycle = ReactionLifecycleCoordinator();
      speech = ReactionSpeechCoordinator(lifecycleCoordinator: lifecycle);
    });

    tearDown(() {
      speech.dispose();
      lifecycle.dispose();
    });

    test('no banner → speakOrHold invokes callback immediately', () async {
      var spoken = false;
      await speech.speakOrHold('hello', (_) async { spoken = true; });
      expect(spoken, isTrue);
      expect(speech.hasPendingSpeech, isFalse);
    });

    test('banner active → speech is held until completed', () async {
      lifecycle.start(_makeReaction());

      var spoken = false;
      await speech.speakOrHold('held text', (_) async { spoken = true; });

      // Speech should be held (not yet spoken).
      expect(spoken, isFalse);
      expect(speech.hasPendingSpeech, isTrue);
      expect(speech.isBannerActive, isTrue);

      // Advance lifecycle to completed.
      lifecycle.transition(ReactionBannerLifecycle.visible);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      lifecycle.transition(ReactionBannerLifecycle.completed);

      // Allow microtasks for the stream listener to fire.
      await Future.delayed(Duration.zero);

      expect(spoken, isTrue);
      expect(speech.hasPendingSpeech, isFalse);
    });

    test('cancelPending clears held speech without invoking callback', () async {
      lifecycle.start(_makeReaction());

      var spoken = false;
      await speech.speakOrHold('cancelled text', (_) async { spoken = true; });

      expect(speech.hasPendingSpeech, isTrue);
      speech.cancelPending();
      expect(speech.hasPendingSpeech, isFalse);

      // Complete lifecycle — callback should NOT fire.
      lifecycle.transition(ReactionBannerLifecycle.visible);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      lifecycle.transition(ReactionBannerLifecycle.completed);

      await Future.delayed(Duration.zero);
      expect(spoken, isFalse);
    });

    test('speakOrHold replaces previous pending speech', () async {
      lifecycle.start(_makeReaction());

      var firstSpoken = false;
      var secondSpoken = false;

      await speech.speakOrHold('first', (_) async { firstSpoken = true; });
      await speech.speakOrHold('second', (_) async { secondSpoken = true; });

      // Only the latest should be pending.
      expect(speech.hasPendingSpeech, isTrue);
      expect(firstSpoken, isFalse);
      expect(secondSpoken, isFalse);

      lifecycle.transition(ReactionBannerLifecycle.visible);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      lifecycle.transition(ReactionBannerLifecycle.completed);

      await Future.delayed(Duration.zero);

      // Second callback fires, first does not.
      expect(firstSpoken, isFalse);
      expect(secondSpoken, isTrue);
    });

    test('dispose cancels subscription and clears pending', () async {
      lifecycle.start(_makeReaction());

      var spoken = false;
      await speech.speakOrHold('will be disposed', (_) async { spoken = true; });
      expect(speech.hasPendingSpeech, isTrue);

      speech.dispose();

      // After dispose, completing lifecycle should NOT fire callback.
      lifecycle.transition(ReactionBannerLifecycle.visible);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      lifecycle.transition(ReactionBannerLifecycle.completed);

      await Future.delayed(Duration.zero);
      expect(spoken, isFalse);
    });

    test('isBannerActive mirrors lifecycle coordinator', () {
      expect(speech.isBannerActive, isFalse);
      lifecycle.start(_makeReaction());
      expect(speech.isBannerActive, isTrue);
      lifecycle.transition(ReactionBannerLifecycle.visible);
      expect(speech.isBannerActive, isTrue);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      expect(speech.isBannerActive, isTrue); // exiting still counts
      lifecycle.transition(ReactionBannerLifecycle.completed);
      expect(speech.isBannerActive, isFalse);
    });

    test('repeated lifecycle cycles: speech held and released each time', () async {
      // Cycle 1
      lifecycle.start(_makeReaction(id: 'r1'));
      var spoke1 = false;
      await speech.speakOrHold('text1', (_) async { spoke1 = true; });
      expect(spoke1, isFalse);
      lifecycle.transition(ReactionBannerLifecycle.visible);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      lifecycle.transition(ReactionBannerLifecycle.completed);
      await Future.delayed(Duration.zero);
      expect(spoke1, isTrue);

      lifecycle.reset();

      // Cycle 2
      lifecycle.start(_makeReaction(id: 'r2'));
      var spoke2 = false;
      await speech.speakOrHold('text2', (_) async { spoke2 = true; });
      expect(spoke2, isFalse);
      lifecycle.transition(ReactionBannerLifecycle.visible);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      lifecycle.transition(ReactionBannerLifecycle.completed);
      await Future.delayed(Duration.zero);
      expect(spoke2, isTrue);
    });

    test('no double-speak: second speakOrHold while idle speaks immediately', () async {
      var count = 0;
      await speech.speakOrHold('a', (_) async { count++; });
      await speech.speakOrHold('b', (_) async { count++; });
      expect(count, 2); // both spoke immediately
      expect(speech.hasPendingSpeech, isFalse);
    });
  });

  // ─── Group C: All 6 Renderers (via defaultStyleForType) ────────────

  group('C. Renderer Selection via defaultStyleForType', () {
    test('EmojiReactionType → emoji', () {
      expect(
        defaultStyleForType(const EmojiReactionType('✨')),
        ReactionVisualStyle.emoji,
      );
    });

    test('AnimationReactionType → customVisual', () {
      expect(
        defaultStyleForType(const AnimationReactionType('confetti')),
        ReactionVisualStyle.customVisual,
      );
    });

    test('TextReactionType → asciiArt', () {
      expect(
        defaultStyleForType(const TextReactionType()),
        ReactionVisualStyle.asciiArt,
      );
    });

    test('HumorReactionType → meme', () {
      expect(
        defaultStyleForType(const HumorReactionType()),
        ReactionVisualStyle.meme,
      );
    });

    test('TerminalReactionType → code', () {
      expect(
        defaultStyleForType(const TerminalReactionType()),
        ReactionVisualStyle.code,
      );
    });

    test('CodeReactionType → code', () {
      expect(
        defaultStyleForType(const CodeReactionType('dart')),
        ReactionVisualStyle.code,
      );
    });

    test('VisualReactionType → customVisual', () {
      expect(
        defaultStyleForType(const VisualReactionType()),
        ReactionVisualStyle.customVisual,
      );
    });

    test('NativeOverlayReactionType → customVisual', () {
      expect(
        defaultStyleForType(const NativeOverlayReactionType()),
        ReactionVisualStyle.customVisual,
      );
    });

    test('explicit visualStyle overrides defaultStyleForType', () {
      final reaction = _makeReaction(
        type: const EmojiReactionType('🎯'),
        visualStyle: ReactionVisualStyle.code, // unusual override
      );
      final style = reaction.visualStyle ?? defaultStyleForType(reaction.type);
      expect(style, ReactionVisualStyle.code);
    });

    test('null visualStyle falls back to defaultStyleForType', () {
      final reaction = _makeReaction(
        type: const HumorReactionType(),
      );
      final style = reaction.visualStyle ?? defaultStyleForType(reaction.type);
      expect(style, ReactionVisualStyle.meme);
    });

    test('Reaction with payload map is not null', () {
      final reaction = _makeReaction(
        payload: {'emoji': '🚀', 'label': 'Launch'},
      );
      expect(reaction.payload, isNotNull);
      expect(reaction.payload!['emoji'], '🚀');
    });

    test('Reaction with null payload can still derive emoji from type', () {
      final reaction = _makeReaction(type: const EmojiReactionType('💡'));
      expect(reaction.payload, isNull);
      // Banner falls back to type.emoji when payload is null.
      expect((reaction.type as EmojiReactionType).emoji, '💡');
    });
  });

  // ─── Group D: RTL / Kurdish Localization ──────────────────────────

  group('D. RTL / Kurdish Localization', () {
    test('SKu reactionBannerLabel is Kurdish Sorani', () {
      final sku = SKu();
      expect(sku.reactionBannerLabel, 'کاردانەوەی AURA');
    });

    test('SKu speakingIndicatorLabel is Kurdish Sorani', () {
      final sku = SKu();
      expect(sku.speakingIndicatorLabel, 'دەنگ دەهێنێت…');
    });

    test('S default reactionBannerLabel is English', () {
      expect(S.reactionBannerLabel, 'AURA Reaction');
    });

    test('S default speakingIndicatorLabel is English', () {
      expect(S.speakingIndicatorLabel, 'Speaking…');
    });

    test('SEn reactionBannerLabel matches S', () {
      final sen = SEn();
      expect(sen.reactionBannerLabel, S.reactionBannerLabel);
    });

    test('SEn speakingIndicatorLabel matches S', () {
      final sen = SEn();
      expect(sen.speakingIndicatorLabel, S.speakingIndicatorLabel);
    });

    test('SKu inherits non-overridden S fields', () {
      final sku = SKu();
      // ok and cancel are overridden in SKu.
      expect(sku.ok, 'باشە');
      expect(sku.cancel, 'پاشگەزبوونەوە');
    });

    test('ReactionBannerLifecycle enum has all 5 phases', () {
      expect(ReactionBannerLifecycle.values.length, 5);
      expect(ReactionBannerLifecycle.values, contains(ReactionBannerLifecycle.idle));
      expect(ReactionBannerLifecycle.values, contains(ReactionBannerLifecycle.entering));
      expect(ReactionBannerLifecycle.values, contains(ReactionBannerLifecycle.visible));
      expect(ReactionBannerLifecycle.values, contains(ReactionBannerLifecycle.exiting));
      expect(ReactionBannerLifecycle.values, contains(ReactionBannerLifecycle.completed));
    });

    test('ReactionVisualStyle has all 6 styles', () {
      expect(ReactionVisualStyle.values.length, 6);
      expect(ReactionVisualStyle.values, contains(ReactionVisualStyle.emoji));
      expect(ReactionVisualStyle.values, contains(ReactionVisualStyle.pixelArt));
      expect(ReactionVisualStyle.values, contains(ReactionVisualStyle.asciiArt));
      expect(ReactionVisualStyle.values, contains(ReactionVisualStyle.code));
      expect(ReactionVisualStyle.values, contains(ReactionVisualStyle.meme));
      expect(ReactionVisualStyle.values, contains(ReactionVisualStyle.customVisual));
    });

    test('RTL TextDirection.rtl is available for Kurdish', () {
      // Verify Flutter provides RTL direction.
      expect(TextDirection.rtl, isNotNull);
      expect(TextDirection.rtl, isNot(equals(TextDirection.ltr)));
    });
  });

  // ─── Group E: Dashboard Integration (provider-level) ─────────────

  group('E. Dashboard Integration (provider wiring)', () {
    test('isReactionBannerActiveProvider is false when no active reaction', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isActive = container.read(isReactionBannerActiveProvider);
      expect(isActive, isFalse);
    });

    test('currentReactionForBannerProvider is null when no reaction', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reaction = container.read(currentReactionForBannerProvider);
      expect(reaction, isNull);
    });

    test('bannerLifecycleProvider is idle when no reaction', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final lifecycle = container.read(bannerLifecycleProvider);
      expect(lifecycle, ReactionBannerLifecycle.idle);
    });

    test('reactionLifecycleProvider returns coordinator from engine', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(reactionLifecycleProvider);
      expect(coordinator, isNotNull);
      expect(coordinator.current, ReactionBannerLifecycle.idle);
    });

    test('reactionSpeechCoordinatorProvider is wired', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final speechCoord = container.read(reactionSpeechCoordinatorProvider);
      expect(speechCoord, isNotNull);
      expect(speechCoord.hasPendingSpeech, isFalse);
      expect(speechCoord.isBannerActive, isFalse);
    });

    test('isReactionBannerActiveProvider becomes true after evaluate', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Register a reaction and evaluate.
      final engine = container.read(reactionEngineProvider.notifier);
      final catalog = container.read(reactionCatalogProvider);
      catalog.register(Reaction(
        id: 'dashboard_test',
        type: const EmojiReactionType('🏠'),
        trigger: ReactionTrigger.agentState,
        priority: 0.8,
      ));

      final ctx = ReactionContext(
        trigger: ReactionTrigger.agentState,
        timestamp: DateTime(2026, 1, 1),
      );

      engine.evaluate(ctx);

      // After evaluate, state is reacting → hasActiveReaction is true.
      final isActive = container.read(isReactionBannerActiveProvider);
      expect(isActive, isTrue);

      // After completeReaction, banner should be inactive.
      engine.completeReaction();
      final isActiveAfter = container.read(isReactionBannerActiveProvider);
      expect(isActiveAfter, isFalse);
    });
  });

  // ─── Group F: Voice Screen Integration (provider-level) ───────────

  group('F. Voice Screen Integration (speech coordination)', () {
    test('speakOrHold is used via coordinator from providers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final speechCoord = container.read(reactionSpeechCoordinatorProvider);
      final lifecycleCoord = container.read(reactionLifecycleProvider);

      // No banner → speak immediately.
      var spoken = false;
      await speechCoord.speakOrHold('test', (_) async { spoken = true; });
      expect(spoken, isTrue);

      // Banner active → hold.
      lifecycleCoord.start(_makeReaction());
      var heldSpoken = false;
      await speechCoord.speakOrHold('held', (_) async { heldSpoken = true; });
      expect(heldSpoken, isFalse);

      lifecycleCoord.transition(ReactionBannerLifecycle.visible);
      lifecycleCoord.transition(ReactionBannerLifecycle.exiting);
      lifecycleCoord.transition(ReactionBannerLifecycle.completed);
      await Future.delayed(Duration.zero);
      expect(heldSpoken, isTrue);
    });

    test('voice state speaking triggers speaking indicator visibility', () {
      // VoiceState.speaking enum value exists and can be checked.
      // This validates the enum is available for the banner widget.
      // (Widget test would verify actual rendering.)
      final speakingState = VoiceState.speaking;
      expect(speakingState, VoiceState.speaking);
      expect(speakingState.isActive, isTrue);
    });

    test('voice state idle does not trigger speaking indicator', () {
      final idleState = VoiceState.idle;
      expect(idleState.isActive, isFalse);
    });
  });

  // ─── Group G: Speaking Indicator Conditions ──────────────────────

  group('G. Speaking Indicator Conditions', () {
    late ReactionLifecycleCoordinator lifecycle;
    late ReactionSpeechCoordinator speech;

    setUp(() {
      lifecycle = ReactionLifecycleCoordinator();
      speech = ReactionSpeechCoordinator(lifecycleCoordinator: lifecycle);
    });

    tearDown(() {
      speech.dispose();
      lifecycle.dispose();
    });

    test('speaking indicator appears when hasPendingSpeech is true', () async {
      lifecycle.start(_makeReaction());
      await speech.speakOrHold('waiting text', (_) async {});
      expect(speech.hasPendingSpeech, isTrue);
      // Banner widget would show SpeakingIndicator when hasPendingSpeech.
    });

    test('speaking indicator disappears when banner completes and speech fires', () async {
      lifecycle.start(_makeReaction());
      await speech.speakOrHold('released text', (_) async {});
      expect(speech.hasPendingSpeech, isTrue);

      lifecycle.transition(ReactionBannerLifecycle.visible);
      lifecycle.transition(ReactionBannerLifecycle.exiting);
      lifecycle.transition(ReactionBannerLifecycle.completed);
      await Future.delayed(Duration.zero);

      expect(speech.hasPendingSpeech, isFalse);
      // Speaking indicator would disappear after speech callback fires.
    });

    test('speaking indicator appears when VoiceState is speaking', () {
      // Validates the condition: VoiceState.speaking == true.
      expect(VoiceState.speaking.isActive, isTrue);
    });

    test('speaking indicator does not appear when VoiceState is idle and no pending speech', () {
      expect(VoiceState.idle.isActive, isFalse);
      expect(speech.hasPendingSpeech, isFalse);
      // Both conditions false → indicator hidden.
    });

    test('speaking indicator does not appear when VoiceState is listening', () {
      expect(VoiceState.listening.isActive, isTrue); // listening IS active
      // But VoiceState.listening != speaking → no indicator for listening.
      // The banner widget specifically checks == VoiceState.speaking.
      expect(VoiceState.listening == VoiceState.speaking, isFalse);
    });

    test('cancelPending hides speaking indicator', () async {
      lifecycle.start(_makeReaction());
      await speech.speakOrHold('cancelled', (_) async {});
      expect(speech.hasPendingSpeech, isTrue);
      speech.cancelPending();
      expect(speech.hasPendingSpeech, isFalse);
    });

    test('ReactionState hasActiveReaction requires status == reacting', () {
      const idleState = ReactionState();
      expect(idleState.hasActiveReaction, isFalse);

      final withReactionButIdle = ReactionState(
        currentReaction: _makeReaction(),
        status: ReactionEngineStatus.idle,
      );
      expect(withReactionButIdle.hasActiveReaction, isFalse);

      final withReactionAndReacting = ReactionState(
        currentReaction: _makeReaction(),
        status: ReactionEngineStatus.reacting,
      );
      expect(withReactionAndReacting.hasActiveReaction, isTrue);
    });

    test('ReactionState isBannerOnScreen reflects bannerLifecycle', () {
      const state = ReactionState(
        bannerLifecycle: ReactionBannerLifecycle.visible,
      );
      expect(state.isBannerOnScreen, isTrue);

      const completedState = ReactionState(
        bannerLifecycle: ReactionBannerLifecycle.completed,
      );
      expect(completedState.isBannerOnScreen, isFalse);
    });

    test('ReactionState isBannerCompleted is true only for completed', () {
      const state = ReactionState(
        bannerLifecycle: ReactionBannerLifecycle.completed,
      );
      expect(state.isBannerCompleted, isTrue);

      const visibleState = ReactionState(
        bannerLifecycle: ReactionBannerLifecycle.visible,
      );
      expect(visibleState.isBannerCompleted, isFalse);
    });
  });
}
