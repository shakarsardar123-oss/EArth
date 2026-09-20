/// Stub implementation of [ScreenCaptureService] for non-Android
/// platforms and test environments.
///
/// Always reports [isSupported] as `false` and returns errors for
/// every capture attempt. Frame stream is always empty.
library;

import 'dart:async';

import '../errors/result.dart';
import '../errors/failures.dart';
import 'screen_capture_state.dart';
import 'screen_capture_result.dart';
import 'screen_capture_service.dart';

/// No-op [ScreenCaptureService] used on iOS / desktop / web where
/// MediaProjection is not available.
class ScreenCaptureStubChannel implements ScreenCaptureService {
  ScreenCaptureStubChannel();

  ScreenCaptureState _state = const ScreenCaptureState();

  @override
  ScreenCaptureState get state => _state;

  @override
  Stream<CapturedFrame> get frameStream =>
      const Stream<CapturedFrame>.empty();

  @override
  bool get isSupported => false;

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> startCapture(
    ScreenCaptureConfig config,
  ) async {
    _state = _state.copyWith(
      status: ScreenCaptureStatus.error,
      lastError: 'Screen capture is not supported on this platform',
    );
    return const Result.failure(
      ScreenCaptureFailure(
        message: 'Screen capture is not supported on this platform',
        phase: ScreenCapturePhase.requestProjection,
      ),
    );
  }

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> stopCapture() async {
    _state = _state.copyWith(
      status: ScreenCaptureStatus.idle,
      clearError: true,
    );
    return Result.success(_state);
  }

  @override
  Future<Result<CapturedFrame, ScreenCaptureFailure>> captureSingleFrame() async {
    return const Result.failure(
      ScreenCaptureFailure(
        message: 'Screen capture is not supported on this platform',
        phase: ScreenCapturePhase.readFrame,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _state = _state.copyWith(
      status: ScreenCaptureStatus.idle,
      clearError: true,
    );
  }
}
