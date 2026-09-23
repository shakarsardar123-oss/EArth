import 'dart:ui';

import '../../../domain/models/screen_target.dart';
import '../../../domain/repositories/screen_action_repository.dart';
import '../../../../core/device/system_control_channel.dart';

/// Android implementation of screen-target actuation.
///
/// Fail-closed:
/// - requires AccessibilityService
/// - requires a verified/actionable target
/// - accepts only tap, longPress and swipe
/// - never reports success unless the native channel confirms dispatch
class AndroidScreenActionRepository implements ScreenActionRepository {
  final SystemControlChannel _systemControl;

  const AndroidScreenActionRepository({
    required SystemControlChannel systemControl,
  }) : _systemControl = systemControl;

  @override
  bool get hasPermission => false;

  @override
  bool get isAvailable => true;

  @override
  Future<ScreenActionResult> tap(ScreenTarget target) async {
    return _dispatchPointGesture(
      target: target,
      gesture: 'tap',
    );
  }

  @override
  Future<ScreenActionResult> longPress(ScreenTarget target) async {
    return _dispatchPointGesture(
      target: target,
      gesture: 'long_press',
      durationMs: 600,
    );
  }

  @override
  Future<ScreenActionResult> swipe({
    required ScreenTarget target,
    required String direction,
  }) async {
    if (!_isVerifiedTarget(target)) {
      return ScreenActionResult.deniedUnverified;
    }

    final sizeResult = await _systemControl.getScreenSize();
    if (!sizeResult.success) {
      return ScreenActionResult.unavailable;
    }

    final width = _intValue(sizeResult.data['width']);
    final height = _intValue(sizeResult.data['height']);

    if (width == null || height == null || width <= 0 || height <= 0) {
      return ScreenActionResult.error;
    }

    final bounds = _bounds(target);
    if (bounds == null) {
      return ScreenActionResult.deniedUnverified;
    }

    final start = _center(bounds);

    final normalizedDirection = direction.trim().toLowerCase();

    double endX = start.dx;
    double endY = start.dy;

    const distance = 0.25;

    switch (normalizedDirection) {
      case 'up':
        endY = (start.dy - height * distance).clamp(0.0, height.toDouble());
        break;
      case 'down':
        endY = (start.dy + height * distance).clamp(0.0, height.toDouble());
        break;
      case 'left':
        endX = (start.dx - width * distance).clamp(0.0, width.toDouble());
        break;
      case 'right':
        endX = (start.dx + width * distance).clamp(0.0, width.toDouble());
        break;
      default:
        return ScreenActionResult.deniedSafety;
    }

    final accessibility =
        await _systemControl.isAccessibilityServiceEnabled();

    if (!accessibility.success ||
        accessibility.data['enabled'] != true) {
      return ScreenActionResult.deniedPermission;
    }

    final result = await _systemControl.dispatchGesture(
      gesture: 'swipe',
      x: start.dx,
      y: start.dy,
      x2: endX,
      y2: endY,
      durationMs: 350,
    );

    return _mapDispatchResult(result);
  }

  @override
  Future<ScreenActionResult> typeText({
    required ScreenTarget target,
    required String text,
  }) async {
    // No real native text-input backend is currently available.
    return ScreenActionResult.unavailable;
  }

  @override
  Future<ScreenActionResult> scroll({
    required ScreenTarget target,
    required String direction,
  }) async {
    // Current SystemControlChannel has no dedicated scroll contract.
    return ScreenActionResult.unavailable;
  }

  Future<ScreenActionResult> _dispatchPointGesture({
    required ScreenTarget target,
    required String gesture,
    int durationMs = 150,
  }) async {
    if (!_isVerifiedTarget(target)) {
      return ScreenActionResult.deniedUnverified;
    }

    final bounds = _bounds(target);
    if (bounds == null) {
      return ScreenActionResult.deniedUnverified;
    }

    final accessibility =
        await _systemControl.isAccessibilityServiceEnabled();

    if (!accessibility.success ||
        accessibility.data['enabled'] != true) {
      return ScreenActionResult.deniedPermission;
    }

    final sizeResult = await _systemControl.getScreenSize();

    if (!sizeResult.success) {
      return ScreenActionResult.unavailable;
    }

    final width = _intValue(sizeResult.data['width']);
    final height = _intValue(sizeResult.data['height']);

    if (width == null || height == null || width <= 0 || height <= 0) {
      return ScreenActionResult.error;
    }

    final center = _center(bounds);

    final pixelX = center.dx * width;
    final pixelY = center.dy * height;

    if (!_insideScreen(pixelX, pixelY, width, height)) {
      return ScreenActionResult.deniedSafety;
    }

    final result = await _systemControl.dispatchGesture(
      gesture: gesture,
      x: pixelX,
      y: pixelY,
      durationMs: durationMs,
    );

    return _mapDispatchResult(result);
  }

  bool _isVerifiedTarget(ScreenTarget target) {
    if (!target.verified || !target.isActionable) {
      return false;
    }

    final bounds = _bounds(target);
    if (bounds == null) {
      return false;
    }

    return bounds.x >= 0 &&
        bounds.y >= 0 &&
        bounds.width > 0 &&
        bounds.height > 0 &&
        bounds.right <= 1 &&
        bounds.bottom <= 1;
  }

  _NormalizedBounds? _bounds(ScreenTarget target) {
    final raw = target.bounds;
    if (raw == null) return null;

    final x = _doubleValue(raw['x']);
    final y = _doubleValue(raw['y']);
    final width = _doubleValue(raw['width']);
    final height = _doubleValue(raw['height']);

    if (x == null || y == null || width == null || height == null) {
      return null;
    }

    if (![
      x,
      y,
      width,
      height,
    ].every(double.isFinite)) {
      return null;
    }

    return _NormalizedBounds(
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  Offset _center(_NormalizedBounds bounds) {
    return Offset(
      bounds.x + bounds.width / 2,
      bounds.y + bounds.height / 2,
    );
  }

  bool _insideScreen(
    double x,
    double y,
    int width,
    int height,
  ) {
    return x >= 0 &&
        y >= 0 &&
        x <= width &&
        y <= height;
  }

  ScreenActionResult _mapDispatchResult(
    DeviceChannelResult result,
  ) {
    if (!result.success) {
      return ScreenActionResult.error;
    }

    final dispatched = result.data['dispatched'] == true;
    final completed = result.data['completed'] == true;

    if (dispatched && completed) {
      return ScreenActionResult.success;
    }

    return ScreenActionResult.error;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  double? _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

class _NormalizedBounds {
  final double x;
  final double y;
  final double width;
  final double height;

  const _NormalizedBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get right => x + width;
  double get bottom => y + height;
}
