/// wake_word_debouncer.dart
/// AURA Assistant – Final Voice Phase: wake-word debounce / cooldown gate.
///
/// Prevents a single spoken "Hey AURA" from firing the session more than once
/// (recognizers can emit several near-simultaneous detections for one
/// utterance) and enforces a cooldown so rapid repeats don't retrigger.
///
/// Also enforces a minimum confidence threshold when the engine reports one.
/// Pure Dart, deterministic (time is injected), unit-tested without an SDK.
library;

/// Gate that decides whether a raw wake detection should be ACCEPTED.
class WakeWordDebouncer {
  WakeWordDebouncer({
    this.cooldown = const Duration(milliseconds: 2500),
    this.minConfidence = 0.5,
  });

  /// Minimum time between two accepted detections.
  final Duration cooldown;

  /// Minimum confidence (0..1) an engine-reported detection must have. When
  /// the engine does not report confidence, pass 1.0 (treated as certain).
  final double minConfidence;

  DateTime? _lastAccepted;

  /// Returns true if this detection should be accepted (fire the wake), or
  /// false if it must be suppressed (duplicate within cooldown, or below the
  /// confidence threshold). [now] is injected for deterministic testing.
  bool shouldAccept({required DateTime now, double confidence = 1.0}) {
    if (confidence < minConfidence) return false;
    final last = _lastAccepted;
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    _lastAccepted = now;
    return true;
  }

  /// Reset the cooldown (e.g. when re-arming after a full session).
  void reset() => _lastAccepted = null;
}
