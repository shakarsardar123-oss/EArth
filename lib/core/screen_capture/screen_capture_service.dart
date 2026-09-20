/// Abstract interface for the AURA screen-capture service.
///
/// Defines the contract for starting/stopping MediaProjection sessions,
/// receiving captured frames, and querying capture state. The concrete
/// implementation uses Android platform channels (MethodChannel +
/// EventChannel) to drive MediaProjection, VirtualDisplay, and
/// ImageReader on the native side.
///
/// Pattern follows [DeviceChannel]: abstract interface + platform impl
/// + stub impl for non-Android / test environments.
library;

import 'dart:async';

import '../errors/result.dart';
import '../errors/failures.dart';
import 'screen_capture_state.dart';
import 'screen_capture_result.dart';

/// Contract for platform-level screen-capture operations.
///
/// Every method returns [Result] so that callers never need to catch
/// platform exceptions — errors are always represented as
/// [ScreenCaptureFailure] values.
abstract class ScreenCaptureService {
  /// Current state of the capture session.
  ScreenCaptureState get state;

  /// Stream of captured frames while the session is active.
  ///
  /// Emits [CapturedFrame] objects as they become available from the
  /// native ImageReader. The stream is throttled to
  /// [ScreenCaptureConfig.maxFramesPerSecond].
  ///
  /// Returns an empty stream if no session is active.
  Stream<CapturedFrame> get frameStream;

  /// Requests MediaProjection access and starts capturing.
  ///
  /// On Android this triggers the system projection dialog. The user
  /// must approve before frames start flowing.
  ///
  /// Returns [Result.success] with the updated [ScreenCaptureState]
  /// on success, or [Result.failure] with a [ScreenCaptureFailure]
  /// if the user denies the projection or setup fails.
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> startCapture(
    ScreenCaptureConfig config,
  );

  /// Stops the active capture session.
  ///
  /// Tears down the VirtualDisplay and releases the MediaProjection.
  /// Returns the updated [ScreenCaptureState] (status → idle).
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> stopCapture();

  /// Captures a single frame synchronously (one-shot).
  ///
  /// Returns [Result.success] with the [CapturedFrame] or
  /// [Result.failure] if no session is active or the read fails.
  Future<Result<CapturedFrame, ScreenCaptureFailure>> captureSingleFrame();

  /// Releases all resources.
  ///
  /// Call in widget dispose / app lifecycle pause to ensure
  /// MediaProjection is stopped even if [stopCapture] was not called.
  Future<void> dispose();

  /// Whether the current platform supports screen capture.
  bool get isSupported;
}
