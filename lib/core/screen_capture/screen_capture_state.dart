/// State model for the AURA screen-capture subsystem.
///
/// Tracks the full lifecycle of a MediaProjection session:
/// idle → requesting → active → stopping → idle.
/// The [requesting] state covers the interval between asking
/// the platform for a projection and receiving the result.
library;

import 'package:meta/meta.dart' show immutable;

/// Lifecycle states of the screen-capture session.
enum ScreenCaptureStatus {
  /// No capture session active.
  idle,

  /// Waiting for the user to approve the MediaProjection dialog.
  requesting,

  /// Capture is active — frames are being produced.
  active,

  /// Capture is being torn down.
  stopping,

  /// An error occurred — capture is not running.
  error;

  /// Whether frames can be captured in this state.
  bool get canCaptureFrames => this == ScreenCaptureStatus.active;

  /// Whether the session can be started from this state.
  bool get canStart => this == ScreenCaptureStatus.idle ||
      this == ScreenCaptureStatus.error;
}

/// Immutable snapshot of the screen-capture subsystem state.
@immutable
class ScreenCaptureState {
  const ScreenCaptureState({
    this.status = ScreenCaptureStatus.idle,
    this.lastError,
    this.frameCount = 0,
    this.lastFrameTimestamp,
    this.captureWidth = 0,
    this.captureHeight = 0,
    this.captureDensity = 0,
  });

  /// Current lifecycle status.
  final ScreenCaptureStatus status;

  /// The most recent error message, if any.
  final String? lastError;

  /// Total number of frames captured since the session started.
  final int frameCount;

  /// Epoch-millis timestamp of the last captured frame.
  final int? lastFrameTimestamp;

  /// Width of the VirtualDisplay / capture surface.
  final int captureWidth;

  /// Height of the VirtualDisplay / capture surface.
  final int captureHeight;

  /// Display density of the capture surface.
  final int captureDensity;

  /// Whether frames can be captured in the current state.
  bool get canCaptureFrames => status.canCaptureFrames;

  /// Whether a new capture session can be started.
  bool get canStart => status.canStart;

  /// Copy-with for state transitions.
  ScreenCaptureState copyWith({
    ScreenCaptureStatus? status,
    String? lastError,
    bool clearError = false,
    int? frameCount,
    int? lastFrameTimestamp,
    int? captureWidth,
    int? captureHeight,
    int? captureDensity,
  }) {
    return ScreenCaptureState(
      status: status ?? this.status,
      lastError: clearError ? null : (lastError ?? this.lastError),
      frameCount: frameCount ?? this.frameCount,
      lastFrameTimestamp: lastFrameTimestamp ?? this.lastFrameTimestamp,
      captureWidth: captureWidth ?? this.captureWidth,
      captureHeight: captureHeight ?? this.captureHeight,
      captureDensity: captureDensity ?? this.captureDensity,
    );
  }

  @override
  String toString() =>
      'ScreenCaptureState(status: $status, frames: $frameCount, '
      'size: ${captureWidth}x$captureHeight, error: $lastError)';
}
