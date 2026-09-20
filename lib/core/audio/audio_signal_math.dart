/// audio_signal_math.dart
/// AURA Assistant – Final Voice Phase: pure-Dart audio signal helpers.
///
/// These are DETERMINISTIC, side-effect-free numeric helpers used by the
/// real audio pipeline (native output-level monitor + echo-safe mic monitor).
/// They contain NO random values and NO fabricated amplitude — every output
/// is a pure function of the audio samples / levels handed in by the native
/// layer. They are unit-tested in `test/core/audio/audio_signal_math_test.dart`
/// because they can run without a Flutter/Android SDK.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Computes the Root-Mean-Square of a block of signed 16-bit PCM samples.
///
/// Returns a value in the linear range 0.0 (silence) .. 1.0 (full-scale),
/// i.e. the RMS divided by the 16-bit full-scale value (32768). This is a
/// genuine energy measure of the samples — not an approximation.
double rmsFromPcm16(Int16List samples) {
  if (samples.isEmpty) return 0.0;
  var sumSquares = 0.0;
  for (final s in samples) {
    final v = s / 32768.0; // normalise to -1..1
    sumSquares += v * v;
  }
  final meanSquare = sumSquares / samples.length;
  return math.sqrt(meanSquare).clamp(0.0, 1.0);
}

/// Peak absolute amplitude of a PCM16 block, normalised 0..1.
double peakFromPcm16(Int16List samples) {
  if (samples.isEmpty) return 0.0;
  var peak = 0;
  for (final s in samples) {
    final a = s.abs();
    if (a > peak) peak = a;
  }
  return (peak / 32768.0).clamp(0.0, 1.0);
}

/// Zero-crossing rate of a PCM16 block (0..1). Used by the energy+ZCR VAD to
/// distinguish voiced speech from steady low-frequency rumble.
double zeroCrossingRate(Int16List samples) {
  if (samples.length < 2) return 0.0;
  var crossings = 0;
  for (var i = 1; i < samples.length; i++) {
    final prev = samples[i - 1];
    final cur = samples[i];
    if ((prev >= 0 && cur < 0) || (prev < 0 && cur >= 0)) crossings++;
  }
  return (crossings / (samples.length - 1)).clamp(0.0, 1.0);
}

/// Maps a raw level onto a normalised 0..1 range using a configurable floor
/// and ceiling, with safe clamping.
///
/// The platform recognizer / Visualizer emits levels in device-dependent
/// units (e.g. Android `speech_to_text` sound level roughly -2..10, or a
/// Visualizer RMS in dBFS-ish units). This class turns any such raw value
/// into a stable 0..1 signal for the waveform. It never invents a value:
/// a raw <= floor becomes 0.0 and a raw >= ceiling becomes 1.0.
class RmsNormalizer {
  RmsNormalizer({required this.floor, required this.ceiling})
      : assert(ceiling > floor, 'ceiling must be > floor');

  /// Raw value that maps to 0.0.
  final double floor;

  /// Raw value that maps to 1.0.
  final double ceiling;

  /// Convenience factory for the Android `speech_to_text` sound-level range.
  factory RmsNormalizer.sttSoundLevel() =>
      RmsNormalizer(floor: -2.0, ceiling: 10.0);

  /// Convenience factory for a linear 0..1 RMS (e.g. from PCM16 rmsFromPcm16),
  /// applying a light gain so quiet speech is still visible without clipping.
  factory RmsNormalizer.linearRms() =>
      RmsNormalizer(floor: 0.0, ceiling: 0.35);

  double normalize(double raw) {
    if (raw.isNaN || raw.isInfinite) return 0.0;
    final t = (raw - floor) / (ceiling - floor);
    return t.clamp(0.0, 1.0);
  }
}

/// Attack/release exponential smoother that removes visual jitter from a
/// 0..1 level stream while staying responsive. Rising edges use the (faster)
/// [attack] coefficient; falling edges use the (slower) [release] coefficient,
/// which gives the waveform a natural "snap up, ease down" motion.
///
/// Deterministic: output depends only on the input sequence and the initial
/// value — no timers, no randomness.
class LevelSmoother {
  LevelSmoother({this.attack = 0.5, this.release = 0.15, double initial = 0.0})
      : assert(attack > 0 && attack <= 1),
        assert(release > 0 && release <= 1),
        _value = initial;

  /// Smoothing coefficient for rising levels (0..1, higher = snappier).
  final double attack;

  /// Smoothing coefficient for falling levels (0..1, lower = slower decay).
  final double release;

  double _value;

  double get value => _value;

  /// Feed the next raw normalised level (0..1); returns the smoothed value.
  double add(double target) {
    final t = target.clamp(0.0, 1.0);
    final coeff = t > _value ? attack : release;
    _value += (t - _value) * coeff;
    if (_value < 0.0001) _value = 0.0;
    return _value;
  }

  void reset([double value = 0.0]) => _value = value.clamp(0.0, 1.0);
}
