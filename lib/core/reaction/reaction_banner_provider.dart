/// Riverpod providers for the Reaction Banner subsystem (Step 5).
///
/// Wires together the lifecycle coordinator and speech coordinator
/// with the reaction engine. Also exposes a provider for the
/// active banner state (used by UI widgets to show/hide the banner).
///
/// Step 5 scope: provider wiring ONLY. No UI.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reaction_engine.dart';
import 'reaction_state.dart';
import 'reaction_model.dart';
import 'reaction_lifecycle.dart';
import 'reaction_speech_coordinator.dart';
import 'reaction_provider.dart';

/// Provider for the [ReactionLifecycleCoordinator].
///
/// This is the SAME coordinator instance used by the engine,
/// exposed separately for UI widgets that need to drive
/// lifecycle transitions.
final reactionLifecycleProvider = Provider<ReactionLifecycleCoordinator>((ref) {
  final engine = ref.watch(reactionEngineProvider.notifier);
  return engine.lifecycleCoordinator;
});

/// Provider for the [ReactionSpeechCoordinator].
///
/// Wires the speech coordinator to the lifecycle coordinator.
final reactionSpeechCoordinatorProvider = Provider<ReactionSpeechCoordinator>((ref) {
  final lifecycle = ref.watch(reactionLifecycleProvider);
  return ReactionSpeechCoordinator(lifecycleCoordinator: lifecycle);
});

/// Provider that exposes whether a reaction banner is currently active.
///
/// UI widgets watch this to determine banner visibility.
final isReactionBannerActiveProvider = Provider<bool>((ref) {
  final state = ref.watch(reactionEngineProvider);
  return state.hasActiveReaction && state.isBannerOnScreen;
});

/// Provider that exposes the current reaction to display in the banner.
///
/// Returns null if no reaction is active.
final currentReactionForBannerProvider = Provider<Reaction?>((ref) {
  final state = ref.watch(reactionEngineProvider);
  if (state.hasActiveReaction) {
    return state.currentReaction;
  }
  return null;
});

/// Provider that exposes the current banner lifecycle phase.
///
/// Used by the banner widget to sync its animation state.
final bannerLifecycleProvider = Provider<ReactionBannerLifecycle>((ref) {
  final state = ref.watch(reactionEngineProvider);
  return state.bannerLifecycle;
});
