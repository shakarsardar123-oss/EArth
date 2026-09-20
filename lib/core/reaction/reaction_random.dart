/// Injectable random source abstraction for testability.
///
/// The production implementation wraps [dart:math Random].
/// Tests inject [DeterministicRandomSource] for reproducible selection.
///
/// This abstraction is needed because the project does not have
/// an existing Random wrapper, and the reaction selector must
/// support controlled randomness for deterministic testing.
library;

import 'dart:math' as math show Random;

/// Abstraction over random number generation.
abstract class RandomSource {
  /// Returns a random double in the range [0.0, 1.0).
  double nextDouble();

  /// Returns a random integer in the range [0, max).
  int nextInt(int max);
}

/// Production random source backed by [dart:math Random].
class DefaultRandomSource implements RandomSource {
  DefaultRandomSource([int? seed]) : _random = math.Random(seed);

  final math.Random _random;

  @override
  double nextDouble() => _random.nextDouble();

  @override
  int nextInt(int max) => _random.nextInt(max);
}

/// Deterministic random source for testing.
///
/// Returns a fixed sequence of values, cycling when exhausted.
/// If no values are provided, always returns 0.0 / 0.
class DeterministicRandomSource implements RandomSource {
  DeterministicRandomSource(this._doubleValues, {List<int>? intValues})
      : _intValues = intValues ?? _doubleValues.map((d) => d.round()).toList();

  final List<double> _doubleValues;
  final List<int> _intValues;
  int _doubleIndex = 0;
  int _intIndex = 0;

  @override
  double nextDouble() {
    if (_doubleValues.isEmpty) return 0.0;
    final value = _doubleValues[_doubleIndex % _doubleValues.length];
    _doubleIndex++;
    return value;
  }

  @override
  int nextInt(int max) {
    if (_intValues.isEmpty) return 0;
    final raw = _intValues[_intIndex % _intValues.length];
    _intIndex++;
    // Ensure result is in [0, max).
    return raw % max;
  }

  /// Reset to initial state (useful for test setup).
  void reset() {
    _doubleIndex = 0;
    _intIndex = 0;
  }
}
