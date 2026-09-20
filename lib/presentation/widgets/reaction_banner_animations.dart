/// Animation controller for the Reaction Banner (Step 5).
///
/// Manages the three-phase animation lifecycle:
///   - entering: slide-down + fade-in
///   - visible: hold / subtle pulse
///   - exiting: slide-up + fade-out
///
/// Phase durations and curves are configurable for testing.
library;

import 'package:flutter/animation.dart';

/// Duration configuration for each banner animation phase.
class ReactionBannerDurations {
  const ReactionBannerDurations({
    this.entering = const Duration(milliseconds: 400),
    this.visible = const Duration(milliseconds: 2200),
    this.exiting = const Duration(milliseconds: 350),
  });

  /// Slide-down + fade-in phase.
  final Duration entering;

  /// Hold / subtle pulse phase (main display time).
  final Duration visible;

  /// Slide-up + fade-out phase.
  final Duration exiting;

  /// Total animation time from entering to completed.
  Duration get total => entering + visible + exiting;
}

/// Default banner animation durations.
const kDefaultBannerDurations = ReactionBannerDurations();

/// Curves used by the banner animation.
class ReactionBannerCurves {
  const ReactionBannerCurves({
    this.entering = Curves.easeOutCubic,
    this.exiting = Curves.easeInCubic,
    this.pulse = Curves.easeInOut,
  });

  /// Curve for the entering slide-down + fade-in.
  final Curve entering;

  /// Curve for the exiting slide-up + fade-out.
  final Curve exiting;

  /// Curve for the subtle pulse during visible phase.
  final Curve pulse;
}

/// Default banner animation curves.
const kDefaultBannerCurves = ReactionBannerCurves();

/// Manages the animation sequence for a reaction banner.
///
/// This class provides the [AnimationController] and derived
/// [Animation] objects for the three phases. It does NOT
/// own any widgets — it is purely an animation driver.
///
/// Usage:
///   1. Create with a [TickerProvider] (from a StatefulWidget)
///   2. Call [playEnter()] to start the entering phase
///   3. After entering completes, call [playVisible()]
///   4. After visible completes, call [playExit()]
///   5. After exit completes, call [onCompleted] callback
///
/// The [slideOffsetAnimation] drives vertical position:
///   0.0 = hidden above screen, 1.0 = fully visible.
///
/// The [opacityAnimation] drives opacity:
///   0.0 = invisible, 1.0 = fully visible.
class ReactionBannerAnimationController {
  ReactionBannerAnimationController({
    required TickerProvider vsync,
    ReactionBannerDurations durations = kDefaultBannerDurations,
    ReactionBannerCurves curves = kDefaultBannerCurves,
    this.onCompleted,
  })  : _durations = durations,
        _curves = curves {
    _controller = AnimationController(
      vsync: vsync,
      duration: _durations.total,
    );

    // Slide offset: 0→1 during entering, hold at 1 during visible,
    // 1→0 during exiting.
    _slideOffsetAnimation = TweenSequence<double>([
      TweenSequenceItem(
        weight: _durations.entering.inMicroseconds.toDouble(),
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: _curves.entering)),
      ),
      TweenSequenceItem(
        weight: _durations.visible.inMicroseconds.toDouble(),
        tween: ConstantTween(1.0),
      ),
      TweenSequenceItem(
        weight: _durations.exiting.inMicroseconds.toDouble(),
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: _curves.exiting)),
      ),
    ]).animate(_controller);

    // Opacity: same pattern but with slight lead-in/lead-out.
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        weight: _durations.entering.inMicroseconds.toDouble(),
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: _curves.entering)),
      ),
      TweenSequenceItem(
        weight: _durations.visible.inMicroseconds.toDouble(),
        tween: ConstantTween(1.0),
      ),
      TweenSequenceItem(
        weight: _durations.exiting.inMicroseconds.toDouble(),
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: _curves.exiting)),
      ),
    ]).animate(_controller);
  }

  final ReactionBannerDurations _durations;
  final ReactionBannerCurves _curves;
  final VoidCallback? onCompleted;

  late final AnimationController _controller;
  late final Animation<double> _slideOffsetAnimation;
  late final Animation<double> _opacityAnimation;

  /// The slide offset animation (0 = hidden, 1 = visible).
  Animation<double> get slideOffsetAnimation => _slideOffsetAnimation;

  /// The opacity animation (0 = invisible, 1 = visible).
  Animation<double> get opacityAnimation => _opacityAnimation;

  /// The underlying [AnimationController].
  AnimationController get controller => _controller;

  /// Whether the animation is currently playing.
  bool get isAnimating => _controller.isAnimating;

  /// Start the full animation sequence (enter → visible → exit).
  void play() {
    _controller.forward(from: 0.0).then((_) {
      onCompleted?.call();
    });
  }

  /// Start the entering phase only.
  void playEnter() {
    final enterFraction =
        _durations.entering.inMicroseconds / _durations.total.inMicroseconds;
    _controller.forward(from: 0.0);
    // Stop at end of entering phase.
    Future.delayed(_durations.entering, () {
      if (_controller.isAnimating) {
        _controller.value = enterFraction;
      }
    });
  }

  /// Start the visible phase (called after entering completes).
  void playVisible() {
    final startFraction =
        _durations.entering.inMicroseconds / _durations.total.inMicroseconds;
    final endFraction =
        (_durations.entering + _durations.visible).inMicroseconds /
            _durations.total.inMicroseconds;
    _controller.forward(from: startFraction);
    Future.delayed(_durations.visible, () {
      if (_controller.isAnimating) {
        _controller.value = endFraction;
      }
    });
  }

  /// Start the exiting phase (called after visible completes).
  void playExit() {
    final startFraction =
        (_durations.entering + _durations.visible).inMicroseconds /
            _durations.total.inMicroseconds;
    _controller.forward(from: startFraction).then((_) {
      onCompleted?.call();
    });
  }

  /// Immediately dismiss the banner (jump to end).
  void dismiss() {
    _controller.forward(from: 1.0);
    onCompleted?.call();
  }

  /// Dispose the animation controller.
  void dispose() {
    _controller.dispose();
  }
}
