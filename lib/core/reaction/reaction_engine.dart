/// Core state notifier for the AURA Dynamic Reaction System.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reaction_catalog.dart';
import 'reaction_context.dart';
import 'reaction_history.dart';
import 'reaction_lifecycle.dart';
import 'reaction_random.dart';
import 'reaction_clock.dart';
import 'reaction_state.dart';
import 'reaction_style_selector.dart';

/// Wires together the catalog, style-aware selector, history, random
/// source, clock, and lifecycle coordinator. [evaluate] is the main
/// entry point — called whenever a trigger occurs, it runs the full
/// selection pipeline and updates [state] if a reaction is chosen.
class ReactionEngine extends StateNotifier<ReactionState> {
  ReactionEngine({
    required ReactionCatalog catalog,
    required StyleAwareSelector selector,
    required ReactionHistory history,
    required RandomSource randomSource,
    required Clock clock,
  })  : _catalog = catalog,
        _selector = selector,
        _history = history,
        _randomSource = randomSource,
        _clock = clock,
        _lifecycleCoordinator = ReactionLifecycleCoordinator(),
        super(ReactionState.initial);

  final ReactionCatalog _catalog;
  final StyleAwareSelector _selector;
  final ReactionHistory _history;
  final RandomSource _randomSource;
  final Clock _clock;
  final ReactionLifecycleCoordinator _lifecycleCoordinator;

  /// Lifecycle coordinator for the active reaction banner.
  ReactionLifecycleCoordinator get lifecycleCoordinator => _lifecycleCoordinator;

  /// Runs the full selection pipeline for [context] and updates state
  /// if a reaction is chosen. No-op if a reaction is already active.
  void evaluate(ReactionContext context) {
    if (state.hasActiveReaction) return;

    state = state.copyWith(status: ReactionEngineStatus.evaluating);

    final selection = _selector.select(
      catalog: _catalog,
      context: context,
      history: _history,
      random: _randomSource,
    );

    if (!selection.hasReaction) {
      state = state.copyWith(status: ReactionEngineStatus.idle);
      return;
    }

    final reaction = selection.reaction!;
    _history.record(reaction.id);
    _lifecycleCoordinator.start(reaction);

    state = state.copyWith(
      status: ReactionEngineStatus.reacting,
      currentReaction: reaction,
      lastReactionId: reaction.id,
      lastSelectedAt: _clock.now(),
      totalSelections: state.totalSelections + 1,
      bannerLifecycle: ReactionBannerLifecycle.entering,
    );
  }

  /// Called by the banner widget as its animation phases complete.
  void transitionBanner(ReactionBannerLifecycle next) {
    _lifecycleCoordinator.transition(next);
    state = state.copyWith(bannerLifecycle: next);

    if (next == ReactionBannerLifecycle.completed) {
      _lifecycleCoordinator.reset();
      state = state.copyWith(
        status: ReactionEngineStatus.idle,
        clearCurrentReaction: true,
        bannerLifecycle: ReactionBannerLifecycle.idle,
      );
    }
  }

  /// Resets the engine to its initial idle state.
  void reset() {
    _lifecycleCoordinator.reset();
    state = ReactionState.initial;
  }

  @override
  void dispose() {
    _lifecycleCoordinator.dispose();
    super.dispose();
  }
}
