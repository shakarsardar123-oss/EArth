/// Hand-written fake [ScreenCaptureService] for voice-screen engine tests.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:aura_assistant/core/screen_capture/screen_capture_service.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_state.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_result.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';

/// Configuration for [FakeScreenCaptureService].
class FakeCaptureConfig {
  /// If non-null, [captureSingleFrame] returns a failure.
  final ScreenCaptureFailure? failure;

  /// The frame to return from [captureSingleFrame].
  /// If null and [failure] is null, a minimal default frame is returned.
  final CapturedFrame? frame;

  /// If true, [captureSingleFrame] throws an unexpected exception.
  final bool shouldThrow;

  /// Delay before returning from [captureSingleFrame].
  final Duration delay;

  const FakeCaptureConfig({
    this.failure,
    this.frame,
    this.shouldThrow = false,
    this.delay = Duration.zero,
  });
}

/// A fake [ScreenCaptureService] with configurable behaviour.
///
/// - Call [configure] before each test to set up expected outcomes.
/// - Tracks call counts and last arguments for assertions.
/// - Broadcasts state changes via [stateStream].
/// - Supports cancellation via [_cancelled] flag.
class FakeScreenCaptureService implements ScreenCaptureService {
  FakeCaptureConfig _config = const FakeCaptureConfig();
  ScreenCaptureState _state = const ScreenCaptureState();
  final _stateController = StreamController<ScreenCaptureState>.broadcast();
  final _frameController = StreamController<CapturedFrame>.broadcast();
  bool _cancelled = false;

  /// Call counts for verification.
  int captureSingleFrameCallCount = 0;
  int stopCaptureCallCount = 0;
  int startCaptureCallCount = 0;
  int disposeCallCount = 0;

  /// Last arguments for verification.
  ScreenCaptureConfig? lastConfig;

  /// Configure the fake's behaviour.
  void configure(FakeCaptureConfig config) {
    _config = config;
  }

  /// Whether the fake was cancelled.
  bool get wasCancelled => _cancelled;

  @override
  ScreenCaptureState get state => _state;

  Stream<ScreenCaptureState> get stateStream => _stateController.stream;

  @override
  bool get isSupported => true;

  @override
  Stream<CapturedFrame> get frameStream => _frameController.stream;

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> startCapture(
    ScreenCaptureConfig config,
  ) async {
    startCaptureCallCount++;
    lastConfig = config;
    _setState(const ScreenCaptureState(status: ScreenCaptureStatus.active));
    return Result.success(_state);
  }

  @override
  Future<Result<CapturedFrame, ScreenCaptureFailure>> captureSingleFrame(
    [ScreenCaptureConfig? config]) async {
    captureSingleFrameCallCount++;
    lastConfig = config;

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    if (_cancelled) {
      return Result.failure(const ScreenCaptureFailure(
        message: 'Capture cancelled',
        phase: ScreenCapturePhase.stopCapture,
      ));
    }

    if (_config.failure != null) {
      return Result.failure(_config.failure!);
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake screen capture service');
    }

    final frame = _config.frame ?? CapturedFrame(
      bytes: Uint8ListSafe(Uint8List.fromList([0, 0, 0, 255])),
      width: 720,
      height: 1280,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _setState(ScreenCaptureState(
      status: ScreenCaptureStatus.active,
      frameCount: 1,
      lastFrameTimestamp: frame.timestamp,
    ));

    return Result.success(frame);
  }

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> stopCapture() async {
    stopCaptureCallCount++;
    _cancelled = true;
    _setState(const ScreenCaptureState(status: ScreenCaptureStatus.idle));
    return Result.success(_state);
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await _stateController.close();
    await _frameController.close();
  }

  void _setState(ScreenCaptureState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
