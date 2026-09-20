/// continuous_listening_service.dart
/// AURA Assistant – Step 27: Continuous Listening & Smart Segmentation
///
/// Domain service contract for continuous listening.
/// FAIL-CLOSED: any error/unknown → inactive, permission denied → denied.
library;

import '../models/listening_session.dart';
import '../models/audio_segment.dart';
import '../models/segmentation_config.dart';

/// Verdict when attempting to start/resume listening.
enum ListeningVerdict {
  allowed,
  denied,
  deniedPermission,
  deniedSafety,
  deniedUnavailable,
  unknown,
  ;

  /// FAIL-CLOSED: only allowed is usable.
  bool get isAllowed => this == allowed;
  bool get isDenied =>
      this == denied ||
      this == deniedPermission ||
      this == deniedSafety ||
      this == deniedUnavailable ||
      this == unknown;
}

/// Abstract domain service for continuous listening.
/// Must be implemented by infrastructure adapters.
abstract class ContinuousListeningService {
  /// Start a new listening session.
  /// Returns verdict — FAIL-CLOSED: any failure → denied.
  Future<ListeningVerdict> startSession({
    required String sessionId,
    required SegmentationConfig config,
  });

  /// Pause an active session.
  /// Returns the updated session; state=inactive if error.
  Future<ListeningSession> pauseSession(String sessionId);

  /// Resume a paused session.
  /// Returns verdict — FAIL-CLOSED: any failure → denied.
  Future<ListeningVerdict> resumeSession(String sessionId);

  /// Stop a session and release resources.
  Future<ListeningSession> stopSession(String sessionId);

  /// Get the current state of a session.
  /// FAIL-CLOSED: unknown → inactive.
  Future<ListeningSession> getSessionState(String sessionId);

  /// Stream of audio segments for a session.
  /// Emits AudioSegment instances as they are segmented.
  /// FAIL-CLOSED: on error, emits invalid segment then closes.
  Stream<AudioSegment> segmentStream(String sessionId);

  /// Check if continuous listening is available on this device.
  bool get isAvailable;

  /// Check if permission has been granted.
  bool get hasPermission;

  /// Update segmentation config for an active session.
  /// Returns updated session; state unchanged if session not found.
  Future<ListeningSession> updateConfig({
    required String sessionId,
    required SegmentationConfig config,
  });
}
