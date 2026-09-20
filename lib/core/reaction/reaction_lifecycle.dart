/// Banner lifecycle states for the AURA Dynamic Reaction System.
///
/// [ReactionBannerLifecycle] tracks the animation lifecycle of a
/// reaction banner: from entering the screen, being visible, exiting,
/// to fully completed. The [ReactionLifecycleCoordinator] manages
/// transitions between these states and exposes a stream for
/// downstream consumers (e.g. speech coordinator) to react to.
///
/// Step 5 scope: lifecycle management ONLY. No UI rendering.
library;

import 'dart:async';

import 'reaction_model.dart';

/// Animation lifecycle of a reaction banner.
///
/// Transition order: idle → entering → visible → exiting → completed → idle
///
/// The banner widget drives entering/visible/exiting transitions
/// via [ReactionLifecycleCoordinator]. The 'completed' state signals
/// that the banner has fully left the screen and speech may proceed.
enum ReactionBannerLifecycle {
  /// No banner is active.
  idle,

  /// Banner is animating into view (slide-down + fade-in).
  entering,

  /// Banner is fully visible and holding.
  visible,

  /// Banner is animating out of view (slide-up + fade-out).
  exiting,

  /// Banner has fully left the screen. Speech may now proceed.
  completed;

  /// Whether the banner is currently on-screen (entering or visible).
  bool get isOnScreen =>
      this == ReactionBannerLifecycle.entering ||
      this == ReactionBannerLifecycle.visible;

  /// Whether the banner lifecycle has finished completely.
  bool get isFinished => this == ReactionBannerLifecycle.completed;
}

/// Coordinates the lifecycle of a reaction banner.
///
/// The banner widget calls [transition] to advance the lifecycle,
/// and [complete] to signal full completion. Downstream consumers
/// (e.g. speech coordinator) listen to [lifecycleStream] to know
/// when the banner is done.
///
/// This coordinator is owned by the [ReactionEngine] and exposed
/// via Riverpod providers. The banner widget calls [transition]
/// as its animation phases complete.
class ReactionLifecycleCoordinator {
  ReactionBannerLifecycle _current = ReactionBannerLifecycle.idle;
  final StreamController<ReactionBannerLifecycle> _controller =
      StreamController<ReactionBannerLifecycle>.broadcast();
  Reaction? _activeReaction;

  /// Current lifecycle phase.
  ReactionBannerLifecycle get current => _current;

  /// The reaction currently being displayed (if any).
  Reaction? get activeReaction => _activeReaction;

  /// Stream of lifecycle transitions for downstream consumers.
  Stream<ReactionBannerLifecycle> get lifecycleStream => _controller.stream;

  /// Whether the coordinator is currently managing an active banner.
  bool get hasActiveBanner => _current.isOnScreen || _current == ReactionBannerLifecycle.exiting;

  /// Start a new banner lifecycle for [reaction].
  ///
  /// Transitions to [ReactionBannerLifecycle.entering].
  /// Throws [StateError] if a banner is already active.
  void start(Reaction reaction) {
    if (hasActiveBanner) {
      throw StateError(
        'Cannot start banner lifecycle: already active ($_current)',
      );
    }
    _activeReaction = reaction;
    _transition(ReactionBannerLifecycle.entering);
  }

  /// Advance to the next lifecycle phase.
  ///
  /// Valid transitions:
  /// - entering → visible
  /// - visible → exiting
  /// - exiting → completed
  ///
  /// Throws [StateError] for invalid transitions.
  void transition(ReactionBannerLifecycle next) {
    final valid = switch ((_current, next)) {
      (ReactionBannerLifecycle.entering, ReactionBannerLifecycle.visible) => true,
      (ReactionBannerLifecycle.visible, ReactionBannerLifecycle.exiting) => true,
      (ReactionBannerLifecycle.exiting, ReactionBannerLifecycle.completed) => true,
      _ => false,
    };
    if (!valid) {
      throw StateError(
        'Invalid lifecycle transition: $_current → $next',
      );
    }
    _transition(next);
  }

  /// Force-complete the current banner lifecycle.
  ///
  /// Skips directly to [completed], bypassing any intermediate phases.
  /// Used when the user dismisses the banner or an error occurs.
  void complete() {
    if (_current == ReactionBannerLifecycle.idle) return;
    _transition(ReactionBannerLifecycle.completed);
  }

  /// Reset to idle. Called after 'completed' has been consumed.
  void reset() {
    _activeReaction = null;
    _transition(ReactionBannerLifecycle.idle);
  }

  void _transition(ReactionBannerLifecycle next) {
    _current = next;
    _controller.add(next);
  }

  /// Dispose the stream controller.
  void dispose() {
    _controller.close();
  }
}
