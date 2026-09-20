/// device_action.dart
///
/// Device-action entity for the `device_integration` feature.
///
/// RECOVERED in P1-RECOVERY step R2. The original source file was absent from
/// the merged tree; this implementation is reconstructed strictly from the
/// behaviour pinned by `test/features/device_integration/device_action_test.dart`
/// (and the other device_integration tests). No behaviour beyond those
/// specifications was invented.
library;

/// A pixel-space offset on the physical screen.
///
/// Deliberately declared here (instead of using `dart:ui`'s `Offset`) so the
/// domain layer stays free of Flutter bindings and is unit-testable on the VM.
class Offset {
  const Offset(this.dx, this.dy);

  /// Horizontal component in device pixels.
  final double dx;

  /// Vertical component in device pixels.
  final double dy;

  @override
  bool operator ==(Object other) =>
      other is Offset && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset($dx, $dy)';
}

/// A point expressed in normalized screen coordinates, where `0.0` is the
/// left/top edge and `1.0` is the right/bottom edge.
///
/// Normalized coordinates keep actions resolution-independent: the same action
/// can be replayed on a different frame size without re-resolving the target.
class NormalizedPoint {
  const NormalizedPoint({required this.x, required this.y})
      : assert(x >= 0.0 && x <= 1.0, 'x must be within [0.0, 1.0]'),
        assert(y >= 0.0 && y <= 1.0, 'y must be within [0.0, 1.0]');

  /// Normalized horizontal coordinate in `[0.0, 1.0]`.
  final double x;

  /// Normalized vertical coordinate in `[0.0, 1.0]`.
  final double y;

  /// Converts this point to a pixel [Offset] for a frame of the given size.
  Offset toPixelOffset(int frameWidth, int frameHeight) =>
      Offset(x * frameWidth, y * frameHeight);

  @override
  bool operator ==(Object other) =>
      other is NormalizedPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'NormalizedPoint(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// The kinds of device interaction the feature can describe.
enum DeviceActionType {
  /// Single tap at a point.
  tap,

  /// Press-and-hold at a point.
  longPress,

  /// Directional swipe between two points.
  swipe,

  /// Text entry, optionally focusing a point first.
  textInput,

  /// System "back" navigation.
  back,

  /// System "home" navigation.
  home,

  /// Launch an application by package name.
  openApp,
}

/// An immutable description of one device interaction.
///
/// A `DeviceAction` is only a *description*. It performs nothing on its own;
/// execution is the responsibility of a platform executor, which may refuse it.
class DeviceAction {
  const DeviceAction({
    required this.type,
    this.targetPoint,
    this.targetLabel,
    this.swipeStart,
    this.swipeEnd,
    this.durationMs,
    this.text,
    this.packageName,
    this.requestId,
  });

  /// Tap at [targetPoint].
  factory DeviceAction.tap({
    required NormalizedPoint targetPoint,
    String? targetLabel,
    String? requestId,
  }) =>
      DeviceAction(
        type: DeviceActionType.tap,
        targetPoint: targetPoint,
        targetLabel: targetLabel,
        requestId: requestId,
      );

  /// Press and hold at [targetPoint] for [durationMs].
  factory DeviceAction.longPress({
    required NormalizedPoint targetPoint,
    int? durationMs,
    String? targetLabel,
    String? requestId,
  }) =>
      DeviceAction(
        type: DeviceActionType.longPress,
        targetPoint: targetPoint,
        durationMs: durationMs,
        targetLabel: targetLabel,
        requestId: requestId,
      );

  /// Swipe from [swipeStart] to [swipeEnd].
  factory DeviceAction.swipe({
    required NormalizedPoint swipeStart,
    required NormalizedPoint swipeEnd,
    int? durationMs,
    String? targetLabel,
    String? requestId,
  }) =>
      DeviceAction(
        type: DeviceActionType.swipe,
        swipeStart: swipeStart,
        swipeEnd: swipeEnd,
        durationMs: durationMs,
        targetLabel: targetLabel,
        requestId: requestId,
      );

  /// Enter [text], optionally focusing [targetPoint] first.
  factory DeviceAction.textInput({
    required String text,
    NormalizedPoint? targetPoint,
    String? targetLabel,
    String? requestId,
  }) =>
      DeviceAction(
        type: DeviceActionType.textInput,
        text: text,
        targetPoint: targetPoint,
        targetLabel: targetLabel,
        requestId: requestId,
      );

  /// System back navigation.
  factory DeviceAction.back({String? requestId}) =>
      DeviceAction(type: DeviceActionType.back, requestId: requestId);

  /// System home navigation.
  factory DeviceAction.home({String? requestId}) =>
      DeviceAction(type: DeviceActionType.home, requestId: requestId);

  /// Launch the app identified by [packageName].
  factory DeviceAction.openApp({
    required String packageName,
    String? requestId,
  }) =>
      DeviceAction(
        type: DeviceActionType.openApp,
        packageName: packageName,
        requestId: requestId,
      );

  /// What kind of interaction this action describes.
  final DeviceActionType type;

  /// Point for point-based actions (`tap`, `longPress`, `textInput` focus).
  final NormalizedPoint? targetPoint;

  /// Human-readable label of the intended target, used for verification and
  /// for the prohibited-target security screen.
  final String? targetLabel;

  /// Swipe origin.
  final NormalizedPoint? swipeStart;

  /// Swipe destination.
  final NormalizedPoint? swipeEnd;

  /// Duration hint in milliseconds for duration-based actions.
  final int? durationMs;

  /// Payload for `textInput`.
  final String? text;

  /// Package name for `openApp`.
  final String? packageName;

  /// Correlation id supplied by the caller, if any.
  final String? requestId;

  /// Whether the type-specific fields required for execution are present.
  ///
  /// This is a *structural* check only — it says nothing about permissions,
  /// security policy, or whether the platform can actually perform the action.
  bool get isValid {
    switch (type) {
      case DeviceActionType.tap:
      case DeviceActionType.longPress:
        return targetPoint != null;
      case DeviceActionType.swipe:
        return swipeStart != null && swipeEnd != null;
      case DeviceActionType.textInput:
        return text != null;
      case DeviceActionType.back:
      case DeviceActionType.home:
        return true;
      case DeviceActionType.openApp:
        return packageName != null;
    }
  }

  @override
  String toString() => 'DeviceAction(${type.name}'
      '${targetLabel != null ? ', label: $targetLabel' : ''}'
      '${targetPoint != null ? ', point: $targetPoint' : ''})';
}
