/// audio_input_repository.dart
/// AURA Assistant – Step 27: Continuous Listening & Smart Segmentation
///
/// Domain repository contract for audio input.
/// FAIL-CLOSED: any error → deny, unavailable → deny.
library;

import '../models/audio_segment.dart';
import '../models/listening_session.dart';
import '../models/segmentation_config.dart';

/// Result of an audio input operation.
enum AudioInputResult {
  success,
  denied,
  deniedPermission,
  unavailable,
  error,
  unknown,
  ;

  bool get isSuccess => this == success;
  bool get isDenied =>
      this == denied ||
      this == deniedPermission ||
      this == unavailable ||
      this == error ||
      this == unknown;
}

/// Abstract repository for audio input (microphone access).
/// Infrastructure adapters must implement this interface EXACTLY.
abstract class AudioInputRepository {
  /// Request microphone permission.
  /// FAIL-CLOSED: denied/unknown → denied.
  Future<AudioInputResult> requestPermission();

  /// Check if microphone permission is currently granted.
  bool get hasPermission;

  /// Start capturing audio for a session.
  /// Returns result — FAIL-CLOSED: any failure → denied.
  Future<AudioInputResult> startCapture({
    required String sessionId,
    required SegmentationConfig config,
  });

  /// Stop capturing audio for a session.
  Future<AudioInputResult> stopCapture(String sessionId);

  /// Stream of raw audio segments.
  /// FAIL-CLOSED: on error, emits invalid segment then closes.
  Stream<AudioSegment> audioSegmentStream(String sessionId);

  /// Check if audio input is available on this device.
  bool get isAvailable;

  /// Get current audio input state.
  /// FAIL-CLOSED: unknown → inactive.
  Future<ListeningState> getCurrentState(String sessionId);
}
