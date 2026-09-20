/// Injectable clock abstraction for time-based operations.
///
/// The production implementation wraps [DateTime.now()].
/// Tests inject [FrozenClock] for deterministic cooldown tracking.
///
/// This abstraction is needed because the project does not have
/// an existing Clock abstraction, and the anti-repetition system
/// requires time-based cooldown checks that must be testable.
library;

/// Abstraction over time for testability.
abstract class Clock {
  /// Returns the current time.
  DateTime now();

  /// Returns the current milliseconds since epoch.
  int millisecondsSinceEpoch();
}

/// Production clock backed by [DateTime.now()].
class DefaultClock implements Clock {
  const DefaultClock();

  @override
  DateTime now() => DateTime.now();

  @override
  int millisecondsSinceEpoch() => now().millisecondsSinceEpoch;
}

/// Frozen clock for testing — always returns a fixed time.
///
/// The time can be advanced manually with [advance].
class FrozenClock implements Clock {
  FrozenClock(DateTime initial) : _time = initial;

  DateTime _time;

  @override
  DateTime now() => _time;

  @override
  int millisecondsSinceEpoch() => _time.millisecondsSinceEpoch;

  /// Advances the clock by [duration].
  void advance(Duration duration) {
    _time = _time.add(duration);
  }

  /// Sets the clock to a specific [time].
  void setTo(DateTime time) {
    _time = time;
  }
}
