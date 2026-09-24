/// Android platform-channel implementation of [ScreenCaptureService].
///
/// Uses a [MethodChannel] for control operations (request projection,
/// start/stop capture) and an [EventChannel] for streaming captured
/// frames back to Dart.
///
/// On non-Android platforms this class is never registered — see
/// [ScreenCaptureStubChannel] instead.
library;

import 'dart:async';

import 'package:flutter/services.dart'
    show MethodChannel, EventChannel, PlatformException;

import '../errors/result.dart';
import '../errors/failures.dart';
import 'screen_capture_state.dart';
import 'screen_capture_result.dart';
import 'screen_capture_service.dart';
import 'screen_capture_constants.dart';

/// MethodChannel + EventChannel implementation of
/// [ScreenCaptureService] for Android.
class ScreenCaptureMethodChannel implements ScreenCaptureService {
  ScreenCaptureMethodChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  Stream<List<int>>? overrideFrameStream,
  })  : _methodChannel = methodChannel ??
            const MethodChannel(screenCaptureMethodChannelName),
        _eventChannel = eventChannel ??
            const EventChannel(screenCaptureEventChannelName),
        _overrideFrameStream = overrideFrameStream;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  /// Optional override for the frame stream (useful in tests).
  final Stream<List<int>>? _overrideFrameStream;

  ScreenCaptureState _state = const ScreenCaptureState();
  Stream<CapturedFrame>? _frameStream;
  StreamSubscription<CapturedFrame>? _frameSubscription;

  @override
  ScreenCaptureState get state => _state;

  @override
  Stream<CapturedFrame> get frameStream =>
      _frameStream ?? const Stream<CapturedFrame>.empty();

  @override
  bool get isSupported => true; // Android supports screen capture.

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> startCapture(
    ScreenCaptureConfig config,
  ) async {
    _state = _state.copyWith(status: ScreenCaptureStatus.requesting);

    try {
      final result = await _methodChannel.invokeMethod<Map>(
        ScreenCaptureMethodNames.requestProjection,
        config.toMap(),
      );

      if (result == null) {
        _state = _state.copyWith(
          status: ScreenCaptureStatus.error,
          lastError: 'Projection request returned null',
        );
        return const Result.failure(
          ScreenCaptureFailure(
            message: 'Projection request returned null',
            phase: ScreenCapturePhase.requestProjection,
          ),
        );
      }

      final granted = result['granted'] as bool? ?? false;
      if (!granted) {
        _state = _state.copyWith(
          status: ScreenCaptureStatus.error,
          lastError: 'MediaProjection permission denied by user',
        );
        return const Result.failure(
          ScreenCaptureFailure(
            message: 'MediaProjection permission denied by user',
            phase: ScreenCapturePhase.requestProjection,
          ),
        );
      }

      // Projection granted — start the VirtualDisplay.
      final startResult = await _methodChannel.invokeMethod<Map>(
        ScreenCaptureMethodNames.startCapture,
        config.toMap(),
      );

      if (startResult == null) {
        _state = _state.copyWith(
          status: ScreenCaptureStatus.error,
          lastError: 'Start capture returned null',
        );
        return const Result.failure(
          ScreenCaptureFailure(
            message: 'Start capture returned null',
            phase: ScreenCapturePhase.setupVirtualDisplay,
          ),
        );

      }

      final started = startResult['started'] as bool? ?? false;
      if (!started) {
        final errorMsg = startResult['error'] as String? ??
            'VirtualDisplay setup failed';
        _state = _state.copyWith(
          status: ScreenCaptureStatus.error,
          lastError: errorMsg,
        );
        return Result.failure(
          ScreenCaptureFailure(
            message: errorMsg,
            phase: ScreenCapturePhase.setupVirtualDisplay,
          ),
        );
      }

      final width = startResult['width'] as int? ?? config.width;
      final height = startResult['height'] as int? ?? config.height;
      final density = startResult['density'] as int? ?? config.density;

      _state = _state.copyWith(
        status: ScreenCaptureStatus.active,
        clearError: true,
        captureWidth: width,
        captureHeight: height,
        captureDensity: density,
        frameCount: 0,
      );

      // Wire up the frame EventChannel.
      _initFrameStream(config);

      return Result.success(_state);
    } on PlatformException catch (e) {
      _state = _state.copyWith(
        status: ScreenCaptureStatus.error,
        lastError: e.message ?? e.code,
      );
      return Result.failure(
        ScreenCaptureFailure(
          message: e.message ?? 'Platform error: ${e.code}',
          phase: ScreenCapturePhase.requestProjection,
        ),
      );
    }
  }

  @override
  Future<Result<ScreenCaptureState, ScreenCaptureFailure>> stopCapture() async {
    if (_state.status == ScreenCaptureStatus.idle) {
      return Result.success(_state);
    }

    _state = _state.copyWith(status: ScreenCaptureStatus.stopping);

    try {
      await _methodChannel.invokeMethod<void>(
        ScreenCaptureMethodNames.stopCapture,
      );
    } on PlatformException catch (e) {
      // Even if the platform call fails, we still clear local state.
      _state = _state.copyWith(
        status: ScreenCaptureStatus.error,
        lastError: e.message ?? 'Stop failed: ${e.code}',
      );
      await _cancelFrameStream();
      return Result.failure(
        ScreenCaptureFailure(
          message: e.message ?? 'Stop failed: ${e.code}',
          phase: ScreenCapturePhase.stopCapture,
        ),
      );
    }

    await _cancelFrameStream();
    _state = _state.copyWith(
      status: ScreenCaptureStatus.idle,
      clearError: true,
      frameCount: 0,
      captureWidth: 0,
      captureHeight: 0,
      captureDensity: 0,
    );
    return Result.success(_state);
  }

  @override
  Future<Result<CapturedFrame, ScreenCaptureFailure>> captureSingleFrame() async {
    if (!_state.canCaptureFrames) {
      return Result.failure(
        ScreenCaptureFailure(
          message: 'Cannot capture frame: session not active '
              '(status: ${_state.status})',
          phase: ScreenCapturePhase.readFrame,
        ),
      );
    }

    try {
      final frameData =
          await _methodChannel.invokeMethod<Map>(
        ScreenCaptureMethodNames.captureSingleFrame,
      );

      if (frameData == null) {
        return const Result.failure(
          ScreenCaptureFailure(
            message: 'Single frame capture returned null',
            phase: ScreenCapturePhase.readFrame,
          ),
        );
      }

      final rawBytes = frameData['bytes'] as List?;
      final width = frameData['width'] as int? ?? 0;
      final height = frameData['height'] as int? ?? 0;
      final timestamp = frameData['timestamp'] as int? ?? 0;
      final rotation = frameData['rotation'] as int? ?? 0;
      final formatName = frameData['pixelFormat'] as String? ?? 'rgba';

      if (rawBytes == null || width == 0 || height == 0) {
        return const Result.failure(
          ScreenCaptureFailure(
            message: 'Incomplete frame data from platform',
            phase: ScreenCapturePhase.readFrame,
          ),
        );
      }

      final frame = CapturedFrame(
        bytes: Uint8ListSafe(List<int>.from(rawBytes)),
        width: width,
        height: height,
        timestamp: timestamp,
        rotation: rotation,
        pixelFormat: PixelFormat.values.firstWhere(
          (e) => e.name == formatName,
          orElse: () => PixelFormat.rgba,
        ),
      );

      _state = _state.copyWith(
        frameCount: _state.frameCount + 1,
        lastFrameTimestamp: timestamp,
      );

      return Result.success(frame);
    } on PlatformException catch (e) {
      return Result.failure(
        ScreenCaptureFailure(
          message: e.message ?? 'Frame read error: ${e.code}',
          phase: ScreenCapturePhase.readFrame,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _cancelFrameStream();
    if (_state.status != ScreenCaptureStatus.idle) {
      await stopCapture();
    }
  }

  // ── Private helpers ─────────────────────────────────────────────

  void _initFrameStream(ScreenCaptureConfig config) {
    if (_overrideFrameStream != null) {
      _frameStream = _overrideFrameStream.map(_mapRawFrame);
    } else {
      _frameStream =
          _eventChannel.receiveBroadcastStream().map(_mapRawFrame);
    }
  }

  CapturedFrame _mapRawFrame(dynamic rawData) {
    if (rawData is! Map) {
      // Unexpected payload — skip or throw.
      throw StateError('Expected Map from frame EventChannel, got $rawData');
    }

    final rawBytes = rawData['bytes'] as List?;
    final width = rawData['width'] as int? ?? 0;
    final height = rawData['height'] as int? ?? 0;
    final timestamp = rawData['timestamp'] as int? ?? 0;
    final rotation = rawData['rotation'] as int? ?? 0;
    final formatName = rawData['pixelFormat'] as String? ?? 'rgba';

    return CapturedFrame(
      bytes: Uint8ListSafe(rawBytes != null ? List<int>.from(rawBytes) : []),
      width: width,
      height: height,
      timestamp: timestamp,
      rotation: rotation,
      pixelFormat: PixelFormat.values.firstWhere(
        (e) => e.name == formatName,
        orElse: () => PixelFormat.rgba,
      ),
    );
  }

  Future<void> _cancelFrameStream() async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    _frameStream = null;
  }
}
