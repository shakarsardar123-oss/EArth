/// Riverpod providers for the AURA screen-capture subsystem.
///
/// Exposes:
/// - [screenCaptureServiceProvider] — the platform-appropriate
///   [ScreenCaptureService] instance.
/// - [screenCaptureStateProvider] — the current [ScreenCaptureState]
///   as a [StateNotifierProvider].
/// - [screenCaptureFrameStreamProvider] — a [StreamProvider] that
///   surfaces captured frames.
///
/// Pattern follows existing AURA provider conventions:
/// Provider for services, StateNotifierProvider for mutable state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/result.dart';
import '../errors/failures.dart';
import 'screen_capture_state.dart';
import 'screen_capture_result.dart';
import 'screen_capture_service.dart';
import 'screen_capture_method_channel.dart';

/// Whether the current platform supports screen capture.
///
/// In production this is determined by [ScreenCaptureMethodChannel];
/// in tests a fake can override this provider.
final screenCaptureSupportedProvider = Provider<bool>((ref) {
  final service = ref.watch(screenCaptureServiceProvider);
  return service.isSupported;
});

/// Platform-appropriate [ScreenCaptureService] singleton.
///
/// Default: [ScreenCaptureMethodChannel] (Android). Override this
/// provider in tests to inject a fake.
final screenCaptureServiceProvider = Provider<ScreenCaptureService>((ref) {
  // On Android the method channel is always available; on iOS / web
  // the stub is used. A real app would check Platform.isAndroid here,
  // but we keep it simple — the method channel reports isSupported.
  return ScreenCaptureMethodChannel();
});

/// StateNotifier that wraps a [ScreenCaptureService] and publishes
/// [ScreenCaptureState] changes to Riverpod.
class ScreenCaptureStateNotifier extends StateNotifier<ScreenCaptureState> {
  ScreenCaptureStateNotifier(this._service) : super(const ScreenCaptureState());

  final ScreenCaptureService _service;
  StreamSubscription<CapturedFrame>? _frameSub;

  /// Current service reference (read-only for tests).
  ScreenCaptureService get service => _service;

  /// Starts a capture session, updating state on each transition.
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> startCapture(
    ScreenCaptureConfig config,
  ) async {
    state = state.copyWith(status: ScreenCaptureStatus.requesting);
    final result = await _service.startCapture(config);

    if (result.isFailure) {
      final failureMessage = result.fold<String>(
        onSuccess: (_) => '',
        onFailure: (f) => f.message,
      );
      state = state.copyWith(
        status: ScreenCaptureStatus.error,
        lastError: failureMessage,
      );
      return result;
    }

    state = _service.state;

    // Subscribe to frame stream to keep frameCount in sync.
    _frameSub = _service.frameStream.listen(
      (frame) {
        state = state.copyWith(
          frameCount: state.frameCount + 1,
          lastFrameTimestamp: frame.timestamp,
        );
      },
      onError: (Object error) {
        state = state.copyWith(
          status: ScreenCaptureStatus.error,
          lastError: error.toString(),
        );
      },
    );

    return result;
  }

  /// Stops the capture session and resets state.
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> stopCapture() async {
    state = state.copyWith(status: ScreenCaptureStatus.stopping);
    await _frameSub?.cancel();
    _frameSub = null;

    final result = await _service.stopCapture();

    if (result.isFailure) {
      final failureMessage = result.fold<String>(
        onSuccess: (_) => '',
        onFailure: (f) => f.message,
      );
      state = state.copyWith(
        status: ScreenCaptureStatus.error,
        lastError: failureMessage,
      );
      return result;
    }

    state = _service.state;
    return result;
  }

  /// Captures a single frame and updates state.
  Future<Result<CapturedFrame, ScreenCaptureFailure>> captureSingleFrame() async {
    return _service.captureSingleFrame();
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

/// StateNotifierProvider for the capture session state.
///
/// Tests can override this with a controlled notifier.
final screenCaptureStateProvider =
    StateNotifierProvider<ScreenCaptureStateNotifier, ScreenCaptureState>(
  (ref) {
    final service = ref.watch(screenCaptureServiceProvider);
    return ScreenCaptureStateNotifier(service);
  },
);

/// StreamProvider that surfaces captured frames from the active
/// session. Emits nothing when no session is active.
final screenCaptureFrameStreamProvider =
    StreamProvider<CapturedFrame>((ref) {
  final service = ref.watch(screenCaptureServiceProvider);
  return service.frameStream;
});
