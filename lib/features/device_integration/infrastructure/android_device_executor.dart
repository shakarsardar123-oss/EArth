/// Android device-action executor.
///
/// Production gesture execution is routed through the real
/// SystemControlChannel -> MainActivity -> AuraAccessibilityService path.
///
/// Fail-closed actions:
/// - back/home: no real native implementation exists yet.
/// - textInput: no real native text-input implementation exists yet.
/// - non-Android: every action fails.
///
/// Coordinates supplied by DeviceAction are normalized (0..1). When frame
/// dimensions are not supplied by the caller, the real Android display size
/// is requested through SystemControlChannel.
library;

import '../../../core/device/android_device_channel.dart';
import '../../../core/device/android_system_control_channel.dart';
import '../../../core/device/device_channel.dart';
import '../../../core/device/system_control_channel.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/device_action.dart';
import '../domain/models/device_integration_failure.dart';

class AndroidDeviceExecutor {
  final DeviceChannel _deviceChannel;
  final SystemControlChannel _systemControlChannel;
  final bool isAndroid;

  AndroidDeviceExecutor({
    this.isAndroid = true,
    DeviceChannel? deviceChannel,
    SystemControlChannel? systemControlChannel,
  })  : _deviceChannel = deviceChannel ?? AndroidDeviceChannel(),
        _systemControlChannel =
            systemControlChannel ?? AndroidSystemControlChannel();

  bool get isPlatformSupported => isAndroid;

  Future<Result<void, DeviceIntegrationFailure>> execute(
    DeviceAction action, {
    int? frameWidth,
    int? frameHeight,
  }) async {
    if (!isAndroid) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'Platform not supported: action ${action.type.name} cannot execute on non-Android.',
          action: action,
        ),
      );
    }

    switch (action.type) {
      case DeviceActionType.openApp:
        return _executeOpenApp(action);

      case DeviceActionType.tap:
        return _executeTap(
          action,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
        );

      case DeviceActionType.longPress:
        return _executeLongPress(
          action,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
        );

      case DeviceActionType.swipe:
        return _executeSwipe(
          action,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
        );

      case DeviceActionType.textInput:
        return Result.failure(
          DeviceIntegrationFailure.execution(
            'Text input is not supported: no real Android text-input '
            'platform implementation is currently wired.',
            action: action,
          ),
        );

      case DeviceActionType.back:
      case DeviceActionType.home:
        return Result.failure(
          DeviceIntegrationFailure.execution(
            'System key action ${action.type.name} is not supported: '
            'no real Android back/home platform implementation is currently wired.',
            action: action,
          ),
        );
    }
  }

  Future<void> cancel() async {
    // No cancellation API exists in the current SystemControlChannel /
    // AccessibilityService contract. Do not pretend cancellation succeeded.
  }

  Future<Result<void, DeviceIntegrationFailure>> _executeTap(
    DeviceAction action, {
    int? frameWidth,
    int? frameHeight,
  }) async {
    final size = await _resolveScreenSize(
      action,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    if (size.isFailure) {
      return Result.failure(size.failureOrNull!);
    }

    final point = action.targetPoint;
    if (point == null) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'Tap action has no targetPoint.',
          action: action,
        ),
      );
    }

    final pixel = point.toPixelOffset(size.value!.$1, size.value!.$2);

    return _dispatchGesture(
      action,
      gesture: 'tap',
      x: pixel.dx,
      y: pixel.dy,
    );
  }

  Future<Result<void, DeviceIntegrationFailure>> _executeLongPress(
    DeviceAction action, {
    int? frameWidth,
    int? frameHeight,
  }) async {
    final size = await _resolveScreenSize(
      action,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    if (size.isFailure) {
      return Result.failure(size.failureOrNull!);
    }

    final point = action.targetPoint;
    if (point == null) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'Long-press action has no targetPoint.',
          action: action,
        ),
      );
    }

    final pixel = point.toPixelOffset(size.value!.$1, size.value!.$2);

    return _dispatchGesture(
      action,
      gesture: 'long_press',
      x: pixel.dx,
      y: pixel.dy,
      durationMs: action.durationMs ?? 600,
    );
  }

  Future<Result<void, DeviceIntegrationFailure>> _executeSwipe(
    DeviceAction action, {
    int? frameWidth,
    int? frameHeight,
  }) async {
    final size = await _resolveScreenSize(
      action,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    if (size.isFailure) {
      return Result.failure(size.failureOrNull!);
    }

    final start = action.swipeStart;
    final end = action.swipeEnd;

    if (start == null || end == null) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'Swipe action requires swipeStart and swipeEnd.',
          action: action,
        ),
      );
    }

    final startPixel = start.toPixelOffset(
      size.value!.$1,
      size.value!.$2,
    );
    final endPixel = end.toPixelOffset(
      size.value!.$1,
      size.value!.$2,
    );

    return _dispatchGesture(
      action,
      gesture: 'swipe',
      x: startPixel.dx,
      y: startPixel.dy,
      x2: endPixel.dx,
      y2: endPixel.dy,
      durationMs: action.durationMs ?? 350,
    );
  }

  Future<Result<void, DeviceIntegrationFailure>> _dispatchGesture(
    DeviceAction action, {
    required String gesture,
    required double x,
    required double y,
    double? x2,
    double? y2,
    int durationMs = 150,
  }) async {
    final accessibility =
        await _systemControlChannel.isAccessibilityServiceEnabled();

    if (accessibility.isFailure) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          accessibility.errorMessage ??
              'Unable to determine AccessibilityService state.',
          action: action,
        ),
      );
    }

    final enabled = accessibility.data?['enabled'] == true;
    if (!enabled) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'AURA AccessibilityService is not enabled/bound.',
          action: action,
        ),
      );
    }

    final result = await _systemControlChannel.dispatchGesture(
      gesture: gesture,
      x: x,
      y: y,
      x2: x2,
      y2: y2,
      durationMs: durationMs,
    );

    if (result.isFailure) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          result.errorMessage ??
              'Android AccessibilityService gesture dispatch failed.',
          action: action,
        ),
      );
    }

    final dispatched = result.data?['dispatched'] == true;
    final completed = result.data?['completed'] == true;

    if (!dispatched || !completed) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'Android reported that the gesture was not completed '
          '(dispatched=$dispatched, completed=$completed).',
          action: action,
        ),
      );
    }

    return const Result.success(null);
  }

  Future<Result<(int, int), DeviceIntegrationFailure>> _resolveScreenSize(
    DeviceAction action, {
    int? frameWidth,
    int? frameHeight,
  }) async {
    if (frameWidth != null && frameHeight != null) {
      if (frameWidth <= 0 || frameHeight <= 0) {
        return Result.failure(
          DeviceIntegrationFailure.execution(
            'Invalid frame dimensions: ${frameWidth}x$frameHeight.',
            action: action,
          ),
        );
      }

      return Result.success((frameWidth, frameHeight));
    }

    if (frameWidth != null || frameHeight != null) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'Both frameWidth and frameHeight must be supplied together.',
          action: action,
        ),
      );
    }

    final result = await _systemControlChannel.getScreenSize();

    if (result.isFailure) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          result.errorMessage ??
              'Unable to determine the Android screen dimensions.',
          action: action,
        ),
      );
    }

    final width = _asPositiveInt(result.data?['width']);
    final height = _asPositiveInt(result.data?['height']);

    if (width == null || height == null) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'Android returned invalid screen dimensions.',
          action: action,
        ),
      );
    }

    return Result.success((width, height));
  }

  int? _asPositiveInt(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.round();

    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;

    return null;
  }

  Future<Result<void, DeviceIntegrationFailure>> _executeOpenApp(
    DeviceAction action,
  ) async {
    final packageName = action.packageName;

    if (packageName == null || packageName.isEmpty) {
      return Result.failure(
        DeviceIntegrationFailure.execution(
          'openApp requires a non-empty packageName.',
          action: action,
        ),
      );
    }

    final result = await _deviceChannel.launchApp(packageName);

    if (result.isSuccess) {
      return const Result.success(null);
    }

    return Result.failure(
      DeviceIntegrationFailure.execution(
        result.errorMessage ?? 'launchApp failed for $packageName',
        action: action,
      ),
    );
  }
}
