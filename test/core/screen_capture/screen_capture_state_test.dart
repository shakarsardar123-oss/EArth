import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/screen_capture/screen_capture_state.dart';

void main() {
  group('ScreenCaptureStatus', () {
    test('idle cannot capture frames', () {
      expect(ScreenCaptureStatus.idle.canCaptureFrames, isFalse);
    });

    test('requesting cannot capture frames', () {
      expect(ScreenCaptureStatus.requesting.canCaptureFrames, isFalse);
    });

    test('active can capture frames', () {
      expect(ScreenCaptureStatus.active.canCaptureFrames, isTrue);
    });

    test('stopping cannot capture frames', () {
      expect(ScreenCaptureStatus.stopping.canCaptureFrames, isFalse);
    });

    test('error cannot capture frames', () {
      expect(ScreenCaptureStatus.error.canCaptureFrames, isFalse);
    });

    test('idle can start a new session', () {
      expect(ScreenCaptureStatus.idle.canStart, isTrue);
    });

    test('requesting cannot start a new session', () {
      expect(ScreenCaptureStatus.requesting.canStart, isFalse);
    });

    test('active cannot start a new session', () {
      expect(ScreenCaptureStatus.active.canStart, isFalse);
    });

    test('stopping cannot start a new session', () {
      expect(ScreenCaptureStatus.stopping.canStart, isFalse);
    });

    test('error can start a new session', () {
      expect(ScreenCaptureStatus.error.canStart, isTrue);
    });

    test('all five statuses exist', () {
      expect(ScreenCaptureStatus.values, hasLength(5));
      expect(
        ScreenCaptureStatus.values,
        containsAll([
          ScreenCaptureStatus.idle,
          ScreenCaptureStatus.requesting,
          ScreenCaptureStatus.active,
          ScreenCaptureStatus.stopping,
          ScreenCaptureStatus.error,
        ]),
      );
    });
  });

  group('ScreenCaptureState', () {
    test('default constructor has idle status and zeroed fields', () {
      const state = ScreenCaptureState();
      expect(state.status, ScreenCaptureStatus.idle);
      expect(state.lastError, isNull);
      expect(state.frameCount, 0);
      expect(state.lastFrameTimestamp, isNull);
      expect(state.captureWidth, 0);
      expect(state.captureHeight, 0);
      expect(state.captureDensity, 0);
    });

    test('canCaptureFrames delegates to status', () {
      const idle = ScreenCaptureState(status: ScreenCaptureStatus.idle);
      const active = ScreenCaptureState(status: ScreenCaptureStatus.active);
      expect(idle.canCaptureFrames, isFalse);
      expect(active.canCaptureFrames, isTrue);
    });

    test('canStart delegates to status', () {
      const idle = ScreenCaptureState(status: ScreenCaptureStatus.idle);
      const requesting =
          ScreenCaptureState(status: ScreenCaptureStatus.requesting);
      const error = ScreenCaptureState(status: ScreenCaptureStatus.error);
      expect(idle.canStart, isTrue);
      expect(requesting.canStart, isFalse);
      expect(error.canStart, isTrue);
    });

    test('copyWith updates specified fields', () {
      const original = ScreenCaptureState();
      final updated = original.copyWith(
        status: ScreenCaptureStatus.active,
        frameCount: 5,
        captureWidth: 720,
        captureHeight: 1280,
        captureDensity: 160,
      );

      expect(updated.status, ScreenCaptureStatus.active);
      expect(updated.frameCount, 5);
      expect(updated.captureWidth, 720);
      expect(updated.captureHeight, 1280);
      expect(updated.captureDensity, 160);
      // Unchanged fields
      expect(updated.lastError, isNull);
      expect(updated.lastFrameTimestamp, isNull);
    });

    test('copyWith clearError removes lastError', () {
      const withError =
          ScreenCaptureState(lastError: 'projection denied');
      final cleared = withError.copyWith(clearError: true);
      expect(cleared.lastError, isNull);
    });

    test('copyWith without clearError preserves lastError', () {
      const withError =
          ScreenCaptureState(lastError: 'projection denied');
      final updated = withError.copyWith(
        status: ScreenCaptureStatus.idle,
      );
      expect(updated.lastError, 'projection denied');
    });

    test('copyWith can update lastError', () {
      const state = ScreenCaptureState();
      final updated = state.copyWith(lastError: 'frame read failed');
      expect(updated.lastError, 'frame read failed');
    });

    test('copyWith can update lastFrameTimestamp', () {
      const state = ScreenCaptureState();
      final updated = state.copyWith(lastFrameTimestamp: 1234567890);
      expect(updated.lastFrameTimestamp, 1234567890);
    });

    test('toString contains status and frame info', () {
      const state = ScreenCaptureState(
        status: ScreenCaptureStatus.active,
        frameCount: 10,
        captureWidth: 720,
        captureHeight: 1280,
      );
      final str = state.toString();
      expect(str, contains('active'));
      expect(str, contains('10'));
      expect(str, contains('720'));
      expect(str, contains('1280'));
    });

    test('full lifecycle state transitions', () {
      const idle = ScreenCaptureState();

      // idle → requesting
      final requesting = idle.copyWith(
        status: ScreenCaptureStatus.requesting,
      );
      expect(requesting.status, ScreenCaptureStatus.requesting);
      expect(requesting.canStart, isFalse);

      // requesting → active (projection granted)
      final active = requesting.copyWith(
        status: ScreenCaptureStatus.active,
        clearError: true,
        captureWidth: 720,
        captureHeight: 1280,
        captureDensity: 160,
      );
      expect(active.status, ScreenCaptureStatus.active);
      expect(active.canCaptureFrames, isTrue);

      // active → stopping
      final stopping = active.copyWith(
        status: ScreenCaptureStatus.stopping,
      );
      expect(stopping.status, ScreenCaptureStatus.stopping);
      expect(stopping.canCaptureFrames, isFalse);

      // stopping → idle
      final returned = stopping.copyWith(
        status: ScreenCaptureStatus.idle,
        clearError: true,
        frameCount: 0,
        captureWidth: 0,
        captureHeight: 0,
        captureDensity: 0,
      );
      expect(returned.status, ScreenCaptureStatus.idle);
      expect(returned.canStart, isTrue);
    });

    test('error path: requesting → error', () {
      const requesting =
          ScreenCaptureState(status: ScreenCaptureStatus.requesting);
      final errored = requesting.copyWith(
        status: ScreenCaptureStatus.error,
        lastError: 'user denied projection',
      );
      expect(errored.status, ScreenCaptureStatus.error);
      expect(errored.lastError, 'user denied projection');
      expect(errored.canStart, isTrue);
    });
  });
}
