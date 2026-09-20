import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_state.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_result.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_service.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_provider.dart';

/// A fake [ScreenCaptureService] for provider tests.
class ProviderFakeScreenCaptureService implements ScreenCaptureService {
  ProviderFakeScreenCaptureService({
    this.isSupportedValue = true,
    this.startCaptureShouldFail = false,
    this.stopCaptureShouldFail = false,
  });

  final bool isSupportedValue;
  final bool startCaptureShouldFail;
  final bool stopCaptureShouldFail;

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
    if (startCaptureShouldFail) {
      _state = _state.copyWith(
        status: ScreenCaptureStatus.error,
        lastError: 'denied',
      );
      return Result.failure(
        const ScreenCaptureFailure(
          message: 'denied',
          phase: ScreenCapturePhase.requestProjection,
        ),
      );
    }

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
    if (stopCaptureShouldFail) {
      _state = _state.copyWith(
        status: ScreenCaptureStatus.error,
        lastError: 'stop failed',
      );
      return Result.failure(
        const ScreenCaptureFailure(
          message: 'stop failed',
          phase: ScreenCapturePhase.stopCapture,
        ),
      );
    }

    _state = const ScreenCaptureState();
    return Result.success(_state);
  }

  @override
  Future<Result<CapturedFrame, ScreenCaptureFailure>> captureSingleFrame() async {
    if (_state.status != ScreenCaptureStatus.active) {
      return Result.failure(
        const ScreenCaptureFailure(
          message: 'not active',
          phase: ScreenCapturePhase.readFrame,
        ),
      );
    }
    return Result.success(
      const CapturedFrame(
        bytes: Uint8ListSafe([0xAB]),
        width: 2,
        height: 2,
        timestamp: 1700000000000,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _frameController.close();
  }

  /// Push a frame into the stream for testing.
  void emitFrame(CapturedFrame frame) {
    _frameController.add(frame);
  }
}

void main() {
  group('screenCaptureServiceProvider', () {
    test('provides a ScreenCaptureService', () {
      final container = ProviderContainer();
      final service = container.read(screenCaptureServiceProvider);
      expect(service, isA<ScreenCaptureService>());
    });

    test('can be overridden with a fake', () {
      final fake = ProviderFakeScreenCaptureService();
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );
      final service = container.read(screenCaptureServiceProvider);
      expect(service, same(fake));
    });
  });

  group('screenCaptureSupportedProvider', () {
    test('reflects the service isSupported value', () {
      final fake = ProviderFakeScreenCaptureService(isSupportedValue: true);
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );
      expect(container.read(screenCaptureSupportedProvider), isTrue);
    });

    test('returns false when service is not supported', () {
      final fake = ProviderFakeScreenCaptureService(isSupportedValue: false);
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );
      expect(container.read(screenCaptureSupportedProvider), isFalse);
    });
  });

  group('screenCaptureStateProvider', () {
    test('initial state is idle', () {
      final fake = ProviderFakeScreenCaptureService();
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );
      final state = container.read(screenCaptureStateProvider);
      expect(state.status, ScreenCaptureStatus.idle);
    });

    test('startCapture updates state to active on success', () async {
      final fake = ProviderFakeScreenCaptureService();
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(screenCaptureStateProvider.notifier);
      final result = await notifier.startCapture(const ScreenCaptureConfig());

      expect(result.isSuccess, isTrue);
      final state = container.read(screenCaptureStateProvider);
      expect(state.status, ScreenCaptureStatus.active);
    });

    test('startCapture sets state to error on failure', () async {
      final fake = ProviderFakeScreenCaptureService(
        startCaptureShouldFail: true,
      );
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(screenCaptureStateProvider.notifier);
      final result = await notifier.startCapture(const ScreenCaptureConfig());

      expect(result.isFailure, isTrue);
      final state = container.read(screenCaptureStateProvider);
      expect(state.status, ScreenCaptureStatus.error);
      expect(state.lastError, 'denied');
    });

    test('stopCapture resets state to idle on success', () async {
      final fake = ProviderFakeScreenCaptureService();
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(screenCaptureStateProvider.notifier);
      await notifier.startCapture(const ScreenCaptureConfig());
      await notifier.stopCapture();

      final state = container.read(screenCaptureStateProvider);
      expect(state.status, ScreenCaptureStatus.idle);
    });

    test('stopCapture sets error state on failure', () async {
      final fake = ProviderFakeScreenCaptureService(
        stopCaptureShouldFail: true,
      );
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(screenCaptureStateProvider.notifier);
      // Start first so stop is meaningful
      await notifier.startCapture(const ScreenCaptureConfig());
      final result = await notifier.stopCapture();

      expect(result.isFailure, isTrue);
      final state = container.read(screenCaptureStateProvider);
      expect(state.status, ScreenCaptureStatus.error);
      expect(state.lastError, 'stop failed');
    });

    test('captureSingleFrame delegates to service', () async {
      final fake = ProviderFakeScreenCaptureService();
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(screenCaptureStateProvider.notifier);
      await notifier.startCapture(const ScreenCaptureConfig());
      final result = await notifier.captureSingleFrame();

      expect(result.isSuccess, isTrue);
      result.when(
        success: (frame) {
          expect(frame.width, 2);
          expect(frame.height, 2);
        },
        failure: (_) => fail('Should not fail'),
      );
    });

    test('frame stream updates frameCount', () async {
      final fake = ProviderFakeScreenCaptureService();
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(screenCaptureStateProvider.notifier);
      await notifier.startCapture(const ScreenCaptureConfig());

      // Emit a frame through the fake's stream
      const frame = CapturedFrame(
        bytes: Uint8ListSafe([1, 2, 3, 4]),
        width: 1,
        height: 1,
        timestamp: 100,
      );
      fake.emitFrame(frame);

      // Allow stream to propagate
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(screenCaptureStateProvider);
      expect(state.frameCount, 1);
      expect(state.lastFrameTimestamp, 100);
    });
  });

  group('ScreenCaptureStateNotifier', () {
    test('exposes service reference', () {
      final fake = ProviderFakeScreenCaptureService();
      final container = ProviderContainer(
        overrides: [
          screenCaptureServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(screenCaptureStateProvider.notifier);
      expect(notifier.service, same(fake));
    });
  });
}
