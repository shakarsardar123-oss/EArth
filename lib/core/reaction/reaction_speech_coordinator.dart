/// Coordinates reaction banner lifecycle with speech synthesis.
///
/// When a reaction banner is active, speech (TTS) must wait until
/// the banner completes its animation. This coordinator holds
/// pending speech in a queue and fires the callback when the
/// banner lifecycle reaches 'completed'.
///
/// Policy A: delay speak() call only. No pause/resume of
/// VoiceServiceImpl. Speech is never interrupted — it simply
/// doesn't start until the banner is done.
///
/// Step 5 scope: coordination logic ONLY. No UI, no TTS.
library;

import 'dart:async';

import 'reaction_lifecycle.dart';

/// Callback type for delivering pending speech.
typedef SpeechCallback = Future<void> Function(String text);

/// Coordinates reaction banner lifecycle with speech synthesis.
///
/// Usage:
/// 1. Subscribe to the lifecycle coordinator's stream.
/// 2. When a reaction fires, call [holdSpeech] to queue speech.
/// 3. When the banner lifecycle reaches 'completed', the coordinator
///    automatically invokes the held speech callback.
/// 4. If no banner is active, [speakOrHold] invokes speech immediately.
class ReactionSpeechCoordinator {
  ReactionSpeechCoordinator({
    required ReactionLifecycleCoordinator lifecycleCoordinator,
  }) : _lifecycleCoordinator = lifecycleCoordinator {
    _subscription = _lifecycleCoordinator.lifecycleStream.listen(_onLifecycleChange);
  }

  final ReactionLifecycleCoordinator _lifecycleCoordinator;
  StreamSubscription<ReactionBannerLifecycle>? _subscription;

  /// Pending speech text (if any).
  String? _pendingText;

  /// Pending speech callback (if any).
  SpeechCallback? _pendingCallback;

  /// Whether speech is currently being held waiting for banner completion.
  bool get hasPendingSpeech => _pendingText != null;

  /// Whether a banner is currently on screen or animating.
  bool get isBannerActive => _lifecycleCoordinator.hasActiveBanner;

  /// The main entry point for speech coordination.
  ///
  /// If no banner is active, calls [callback] immediately with [text].
  /// If a banner is active, holds [text] and [callback] until the
  /// banner lifecycle reaches 'completed', then invokes the callback.
  ///
  /// Only one pending speech can be held at a time. Calling this
  /// again while speech is pending replaces the previous pending speech.
  Future<void> speakOrHold(String text, SpeechCallback callback) async {
    if (!_lifecycleCoordinator.hasActiveBanner) {
      // No banner active — speak immediately.
      await callback(text);
      return;
    }

    // Banner is active — hold speech until banner completes.
    _pendingText = text;
    _pendingCallback = callback;
  }

  /// Cancel any pending speech without invoking the callback.
  void cancelPending() {
    _pendingText = null;
    _pendingCallback = null;
  }

  /// Internal handler for lifecycle stream changes.
  void _onLifecycleChange(ReactionBannerLifecycle phase) {
    if (phase == ReactionBannerLifecycle.completed && _pendingText != null) {
      final text = _pendingText!;
      final callback = _pendingCallback!;
      _pendingText = null;
      _pendingCallback = null;

      // Fire the pending speech callback asynchronously.
      callback(text);
    }
  }

  /// Dispose the stream subscription.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _pendingText = null;
    _pendingCallback = null;
  }
}
