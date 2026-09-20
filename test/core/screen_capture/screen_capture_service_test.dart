import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_service.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_state.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_result.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_method_channel.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_stub_channel.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_constants.dart';

// ── Fake implementation ─────────────────────────────────────────

/// A hand-written fake of [ScreenCaptureService] for testing.
///
/// Allows controlling the behavior of each method and tracking
/// call counts.
class FakeScreenCaptureService implements ScreenCaptureService {
  FakeScreenCaptureService({
    this.isSupportedValue = true,
    this.startCaptureResult,
    this.stopCaptureResult,
    this.captureSingleFrameResult,
  });

  bool isSupportedValue;
  Result<ScreenCaptureState, ScreenCaptureFailure>? startCaptureResult;
  Result<ScreenCaptureState, ScreenCaptureFailure>? stopCaptureResult;
  Result<CapturedFrame, ScreenCaptureFailure>? captureSingleFrameResult;

  int startCaptureCallCount = 0;
  int stopCaptureCallCount = 0;
  int captureSingleFrameCallCount = 0;
  int disposeCallCount = 0;
  ScreenCaptureConfig? lastConfig;

  ScreenCaptureState _state = const ScreenCaptureState();
  final StreamController<CapturedFrame> _frameController =
      StreamController<CapturedFrame>.broadcast();

  @override
  ScreenCaptureState get state => _state;

  @override
  Stream<CapturedFrame> get frameStream => _frameController.stream;

  @override
  bool get isSupported => isSupportedValue;

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> startCapture(
    ScreenCaptureConfig config,
  ) async {
    startCaptureCallCount++;
    lastConfig = config;

    if (startCaptureResult != null) {
      if (startCaptureResult!.isSuccess) {
        _state = startCaptureResult!.when(
          success: (s) => s,
          failure: (_) => _state,
        );
      }
      return startCaptureResult!;
    }

    // Default success path.
    _state = ScreenCaptureState(
      status: ScreenCaptureStatus.active,
      captureWidth: config.width,
      captureHeight: config.height,
      captureDensity: config.density,
    );
    return Result.success(_state);
  }

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> stopCapture() async {
    stopCaptureCallCount++;

    if (stopCaptureResult != null) {
      if (stopCaptureResult!.isSuccess) {
        _state = stopCaptureResult!.when(
          success: (s) => s,
          failure: (_) => _state,
        );
      }
      return stopCaptureResult!;
    }

    _state = const ScreenCaptureState();
    return Result.success(_state);
  }

  @override
  Future<Result<CapturedFrame, ScreenCaptureFailure>> captureSingleFrame() async {
    captureSingleFrameCallCount++;

    if (captureSingleFrameResult != null) {
      return captureSingleFrameResult!;
    }

    if (_state.status != ScreenCaptureStatus.active) {
      return Result.failure(
        ScreenCaptureFailure(
          message: 'Not active',
          phase: ScreenCapturePhase.readFrame,
        ),
      );
    }

    return Result.success(
      const CapturedFrame(
        bytes: Uint8ListSafe([0xFF]),
        width: 1,
        height: 1,
        timestamp: 1700000000000,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await _frameController.close();
  }

  /// Test helper: push a frame into the stream.
  void emitFrame(CapturedFrame frame) {
    _frameController.add(frame);
  }
}

void main() {
  // ── ScreenCaptureService (interface contract) ──────────────

  group('ScreenCaptureService interface', () {
    test('FakeScreenCaptureService implements ScreenCaptureService', () {
      final fake = FakeScreenCaptureService();
      expect(fake, isA<ScreenCaptureService>());
    });

    test('default isSupported is true', () {
      final fake = FakeScreenCaptureService();
      expect(fake.isSupported, isTrue);
    });

    test('isSupported can be overridden', () {
      final fake = FakeScreenCaptureService(isSupportedValue: false);
      expect(fake.isSupported, isFalse);
    });
  });

  // ── Fake startCapture ────────────────────────────────────

  group('FakeScreenCaptureService.startCapture', () {
    test('increments call count and records config', () async {
      final fake = FakeScreenCaptureService();
      const config = ScreenCaptureConfig(width: 1080, height: 1920);

      await fake.startCapture(config);

      expect(fake.startCaptureCallCount, 1);
      expect(fake.lastConfig, config);
    });

    test('returns success with active state by default', () async {
      final fake = FakeScreenCaptureService();
      const config = ScreenCaptureConfig();

      final result = await fake.startCapture(config);

      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) {
          expect(state.status, ScreenCaptureStatus.active);
          expect(state.captureWidth, 720);
          expect(state.captureHeight, 1280);
        },
        failure: (_) => fail('Should not fail'),
      );
    });

    test('returns configured failure result', () async {
      final fake = FakeScreenCaptureService(
        startCaptureResult: Result.failure(
          const ScreenCaptureFailure(
            message: 'user denied',
            phase: ScreenCapturePhase.requestProjection,
          ),
        ),
      );

      final result = await fake.startCapture(ScreenCaptureConfig());

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should not succeed'),
        failure: (failure) {
          expect(failure.message, 'user denied');
          expect(failure.phase, ScreenCapturePhase.requestProjection);
        },
      );
    });
  });

  // ── Fake stopCapture ───────────────────────────────────────

  group('FakeScreenCaptureService.stopCapture', () {
    test('increments call count', () async {
      final fake = FakeScreenCaptureService();
      await fake.stopCapture();
      expect(fake.stopCaptureCallCount, 1);
    });

    test('returns success with idle state by default', () async {
      final fake = FakeScreenCaptureService();
      final result = await fake.stopCapture();

      expect(result.isSuccess, isTrue);
      result.when(
        success: (state) => expect(state.status, ScreenCaptureStatus.idle),
        failure: (_) => fail('Should not fail'),
      );
    });
  });

  // ── Fake captureSingleFrame ───────────────────────────────

  group('FakeScreenCaptureService.captureSingleFrame', () {
    test('returns failure when not active', () async {
      final fake = FakeScreenCaptureService();
      // State is idle by default
      final result = await fake.captureSingleFrame();

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should not succeed'),
        failure: (f) {
          expect(f.phase, ScreenCapturePhase.readFrame);
        },
      );
    });

    test('returns success with frame when active', () async {
      final fake = FakeScreenCaptureService();
      await fake.startCapture(const ScreenCaptureConfig());

      final result = await fake.captureSingleFrame();

      expect(result.isSuccess, isTrue);
      result.when(
        success: (frame) {
          expect(frame.width, 1);
          expect(frame.height, 1);
        },
        failure: (_) => fail('Should not fail'),
      );
    });

    test('can override captureSingleFrame result', () async {
      final fake = FakeScreenCaptureService(
        captureSingleFrameResult: Result.failure(
          const ScreenCaptureFailure(
            message: 'read error',
            phase: ScreenCapturePhase.readFrame,
          ),
        ),
      );

      final result = await fake.captureSingleFrame();
      expect(result.isFailure, isTrue);
    });
  });

  // ── Fake frame stream ─────────────────────────────────────

  group('FakeScreenCaptureService.frameStream', () {
    test('emits frames when emitFrame is called', () async {
      final fake = FakeScreenCaptureService();
      final frames = <CapturedFrame>[];

      fake.frameStream.listen(frames.add);

      const frame = CapturedFrame(
        bytes: Uint8ListSafe([1, 2, 3]),
        width: 10,
        height: 10,
        timestamp: 100,
      );
      fake.emitFrame(frame);

      // Allow stream to propagate
      await Future<void>.delayed(Duration.zero);

      expect(frames, hasLength(1));
      expect(frames.first.timestamp, 100);
    });
  });

  // ── Fake dispose ──────────────────────────────────────────

  group('FakeScreenCaptureService.dispose', () {
    test('increments dispose count', () async {
      final fake = FakeScreenCaptureService();
      await fake.dispose();
      expect(fake.disposeCallCount, 1);
    });
  });

  // ── ScreenCaptureStubChannel ──────────────────────────────

  group('ScreenCaptureStubChannel', () {
    late ScreenCaptureStubChannel stub;

    setUp(() {
      stub = ScreenCaptureStubChannel();
    });

    test('implements ScreenCaptureService', () {
      expect(stub, isA<ScreenCaptureService>());
    });

    test('isSupported is false', () {
      expect(stub.isSupported, isFalse);
    });

    test('state defaults to idle', () {
      expect(stub.state.status, ScreenCaptureStatus.idle);
    });

    test('frameStream is always empty', () async {
      final frames = <CapturedFrame>[];
      stub.frameStream.listen(frames.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(frames, isEmpty);
    });

    test('startCapture returns failure', () async {
      final result = await stub.startCapture(const ScreenCaptureConfig());

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should not succeed'),
        failure: (f) {
          expect(f.message, contains('not supported'));
          expect(f.phase, ScreenCapturePhase.requestProjection);
        },
      );
    });

    test('startCapture sets state to error', () async {
      await stub.startCapture(const ScreenCaptureConfig());
      expect(stub.state.status, ScreenCaptureStatus.error);
      expect(stub.state.lastError, contains('not supported'));
    });

    test('stopCapture returns success with idle state', () async {
      final result = await stub.stopCapture();

      expect(result.isSuccess, isTrue);
      result.when(
        success: (s) => expect(s.status, ScreenCaptureStatus.idle),
        failure: (_) => fail('Should not fail'),
      );
    });

    test('captureSingleFrame returns failure', () async {
      final result = await stub.captureSingleFrame();

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should not succeed'),
        failure: (f) {
          expect(f.phase, ScreenCapturePhase.readFrame);
        },
      );
    });

    test('dispose resets state to idle', () async {
      await stub.startCapture(const ScreenCaptureConfig());
      expect(stub.state.status, ScreenCaptureStatus.error);

      await stub.dispose();
      expect(stub.state.status, ScreenCaptureStatus.idle);
    });
  });

  // ── ScreenCaptureMethodChannel ────────────────────────────

  group('ScreenCaptureMethodChannel', () {
    test('implements ScreenCaptureService', () {
      // Cannot test actual platform calls but verify type.
      final channel = ScreenCaptureMethodChannel();
      expect(channel, isA<ScreenCaptureService>());
    });

    test('isSupported is true', () {
      final channel = ScreenCaptureMethodChannel();
      expect(channel.isSupported, isTrue);
    });

    test('initial state is idle', () {
      final channel = ScreenCaptureMethodChannel();
      expect(channel.state.status, ScreenCaptureStatus.idle);
    });
  });

  // ── ScreenCaptureConstants ────────────────────────────────

  group('ScreenCaptureConstants', () {
    test('channel names follow convention', () {
      expect(
        screenCaptureMethodChannelName,
        'com.aura.aura_assistant/screen_capture',
      );
      expect(
        screenCaptureEventChannelName,
        'com.aura.aura_assistant/screen_capture_frames',
      );
    });

    test('method names are all non-empty strings', () {
      expect(ScreenCaptureMethodNames.requestProjection, isNotEmpty);
      expect(ScreenCaptureMethodNames.startCapture, isNotEmpty);
      expect(ScreenCaptureMethodNames.stopCapture, isNotEmpty);
      expect(ScreenCaptureMethodNames.captureSingleFrame, isNotEmpty);
      expect(ScreenCaptureMethodNames.isSupported, isNotEmpty);
    });

    test('method name values match expected strings', () {
      expect(
        ScreenCaptureMethodNames.requestProjection,
        'requestProjection',
      );
      expect(ScreenCaptureMethodNames.startCapture, 'startCapture');
      expect(ScreenCaptureMethodNames.stopCapture, 'stopCapture');
      expect(
        ScreenCaptureMethodNames.captureSingleFrame,
        'captureSingleFrame',
      );
      expect(ScreenCaptureMethodNames.isSupported, 'isSupported');
    });
  });
}
