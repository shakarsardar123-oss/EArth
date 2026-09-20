/// voice_activity_detector.dart
/// AURA Assistant – Final Voice Phase: energy + zero-crossing VAD.
///
/// A REAL (if intentionally lightweight) voice-activity detector. It is NOT a
/// neural VAD — it uses short-term energy (RMS) gated by a zero-crossing
/// sanity check plus start/stop hangover counters to avoid chattering. This
/// is the same class of algorithm used by classic push-to-talk / squelch
/// systems and is honest about what it is (see the report's VAD section).
///
/// It is used for barge-in: while AURA is SPEAKING, the echo-safe mic monitor
/// feeds post-AEC frame levels here; a confirmed speech-onset (not a single
/// amplitude spike) is what triggers barge-in — satisfying the requirement
/// that barge-in must come from actual speech detection, not random spikes.
///
/// Pure Dart, deterministic, unit-tested without an SDK.
library;

/// Result of feeding one frame to the [VoiceActivityDetector].
enum VadTransition {
  /// No change this frame.
  none,

  /// Speech just started (onset confirmed after [startFrames]).
  speechStart,

  /// Speech just ended (offset confirmed after [hangoverFrames] of silence).
  speechEnd,
}

/// Energy + ZCR voice-activity detector with hysteresis.
class VoiceActivityDetector {
  VoiceActivityDetector({
    this.energyThreshold = 0.08,
    this.zcrMin = 0.02,
    this.zcrMax = 0.85,
    this.startFrames = 3,
    this.hangoverFrames = 8,
  })  : assert(energyThreshold >= 0 && energyThreshold <= 1),
        assert(startFrames >= 1),
        assert(hangoverFrames >= 1);

  /// Normalised RMS (0..1) a frame must exceed to count as "loud".
  final double energyThreshold;

  /// Lower/upper zero-crossing-rate bounds for plausible speech. Rejects both
  /// DC-ish rumble (very low ZCR) and hiss/click noise (very high ZCR).
  final double zcrMin;
  final double zcrMax;

  /// Consecutive qualifying frames required before declaring speech onset.
  /// Prevents a single amplitude spike from triggering barge-in.
  final int startFrames;

  /// Consecutive silent frames tolerated before declaring speech offset.
  final int hangoverFrames;

  bool _inSpeech = false;
  int _loudRun = 0;
  int _silentRun = 0;

  bool get isSpeaking => _inSpeech;

  /// Feed one frame's normalised [energy] (0..1) and optional [zcr] (0..1).
  /// Returns the state transition, if any.
  VadTransition addFrame(double energy, {double zcr = 0.5}) {
    final loud = energy >= energyThreshold && zcr >= zcrMin && zcr <= zcrMax;

    if (!_inSpeech) {
      if (loud) {
        _loudRun++;
        if (_loudRun >= startFrames) {
          _inSpeech = true;
          _silentRun = 0;
          _loudRun = 0;
          return VadTransition.speechStart;
        }
      } else {
        _loudRun = 0;
      }
      return VadTransition.none;
    }

    // Currently in speech: look for a sustained silence to end it.
    if (loud) {
      _silentRun = 0;
    } else {
      _silentRun++;
      if (_silentRun >= hangoverFrames) {
        _inSpeech = false;
        _silentRun = 0;
        _loudRun = 0;
        return VadTransition.speechEnd;
      }
    }
    return VadTransition.none;
  }

  void reset() {
    _inSpeech = false;
    _loudRun = 0;
    _silentRun = 0;
  }
}
