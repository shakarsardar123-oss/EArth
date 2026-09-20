/// Hand-written fake [ScreenUnderstandingService] for voice-screen engine tests.
library;

import 'dart:async';

import 'package:aura_assistant/core/screen_understanding/screen_understanding_service.dart';
import 'package:aura_assistant/core/screen_understanding/screen_understanding_state.dart';
import 'package:aura_assistant/core/screen_understanding/screen_understanding_result.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_result.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';

/// Configuration for [FakeScreenUnderstandingService].
class FakeUnderstandingConfig {
  /// If non-null, [analyzeFrame] returns a failure.
  final ScreenUnderstandingFailure? failure;

  /// The representation to return from [analyzeFrame].
  /// If null and [failure] is null, a minimal default is returned.
  final ScreenRepresentation? representation;

  /// If true, [analyzeFrame] throws an unexpected exception.
  final bool shouldThrow;

  /// Delay before returning from [analyzeFrame].
  final Duration delay;

  /// If true, cancellation (via [cancel]) causes the next
  /// [analyzeFrame] call to return a cancelled failure.
  final bool supportCancellation;

  const FakeUnderstandingConfig({
    this.failure,
    this.representation,
    this.shouldThrow = false,
    this.delay = Duration.zero,
    this.supportCancellation = true,
  });
}

/// A fake [ScreenUnderstandingService] with configurable behaviour.
///
/// - Call [configure] before each test to set up expected outcomes.
/// - Tracks call counts and last arguments for assertions.
/// - Broadcasts state changes via [stateStream].
/// - Supports cancellation via [_cancelled] flag.
class FakeScreenUnderstandingService implements ScreenUnderstandingService {
  FakeUnderstandingConfig _config = const FakeUnderstandingConfig();
  ScreenUnderstandingState _state = const ScreenUnderstandingState();
  final _stateController =
      StreamController<ScreenUnderstandingState>.broadcast();
  bool _cancelled = false;

  /// Call counts for verification.
  int analyzeFrameCallCount = 0;
  int analyzeLatestFrameCallCount = 0;
  int cancelCallCount = 0;
  int disposeCallCount = 0;

  /// Last arguments for verification.
  CapturedFrame? lastFrame;

  /// Configure the fake's behaviour.
  void configure(FakeUnderstandingConfig config) {
    _config = config;
  }

  /// Whether the fake was cancelled.
  bool get wasCancelled => _cancelled;

  @override
  ScreenUnderstandingState get state => _state;

  @override
  Stream<ScreenUnderstandingState> get stateStream =>
      _stateController.stream;

  /// Creates a minimal default [ScreenRepresentation] for testing.
  ScreenRepresentation _defaultRepresentation() => ScreenRepresentation(
        metadata: ScreenMetadata(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          width: 720,
          height: 1280,
        ),
      );

  @override
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      analyzeFrame(CapturedFrame frame) async {
    analyzeFrameCallCount++;
    lastFrame = frame;

    _setState(const ScreenUnderstandingState(
      status: ScreenUnderstandingStatus.analyzing,
    ));

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    if (_cancelled && _config.supportCancellation) {
      _setState(const ScreenUnderstandingState(
        status: ScreenUnderstandingStatus.cancelled,
      ));
      return Result.failure(const ScreenUnderstandingFailure(
        message: 'Analysis cancelled',
        phase: ScreenUnderstandingPhase.cancelled,
      ));
    }

    if (_config.failure != null) {
      _setState(ScreenUnderstandingState(
        status: ScreenUnderstandingStatus.error,
        errorMessage: _config.failure!.message,
      ));
      return Result.failure(_config.failure!);
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake understanding service');
    }

    final representation = _config.representation ?? _defaultRepresentation();

    _setState(ScreenUnderstandingState(
      status: ScreenUnderstandingStatus.success,
      representation: representation,
      lastAnalysisTimestamp: DateTime.now().millisecondsSinceEpoch,
      analysisCount: 1,
    ));

    return Result.success(representation);
  }

  @override
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      analyzeLatestFrame(Stream<CapturedFrame> frameStream) async {
    analyzeLatestFrameCallCount++;

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    if (_cancelled && _config.supportCancellation) {
      return Result.failure(const ScreenUnderstandingFailure(
        message: 'Analysis cancelled',
        phase: ScreenUnderstandingPhase.cancelled,
      ));
    }

    if (_config.failure != null) {
      return Result.failure(_config.failure!);
    }

    // Listen to the stream, take the latest frame.
    CapturedFrame? latestFrame;
    try {
      latestFrame = await frameStream.first;
    } catch (_) {
      // Stream closed without a frame — use default representation.
    }

    if (latestFrame != null) {
      lastFrame = latestFrame;
    }

    final representation = _config.representation ?? _defaultRepresentation();
    return Result.success(representation);
  }

  @override
  void cancel() {
    cancelCallCount++;
    _cancelled = true;
    _setState(const ScreenUnderstandingState(
      status: ScreenUnderstandingStatus.cancelled,
    ));
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await _stateController.close();
  }

  void _setState(ScreenUnderstandingState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
