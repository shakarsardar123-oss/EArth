import '../../domain/models/correction_action.dart';
import '../../domain/models/screen_target.dart';
import '../../domain/services/screen_correction_service.dart';

/// Conservative screen-action policy.
///
/// Only tap, long-press and swipe are executable because those are the
/// operations currently supported by SystemControlChannel.
///
/// Everything else remains fail-closed.
class AndroidScreenCorrectionService implements ScreenCorrectionService {
  const AndroidScreenCorrectionService();

  @override
  bool isTargetVerified(ScreenTarget target) {
    if (!target.verified) return false;
    if (!target.isActionable) return false;

    final bounds = target.bounds;
    if (bounds == null) return false;

    final x = _number(bounds['x']);
    final y = _number(bounds['y']);
    final width = _number(bounds['width']);
    final height = _number(bounds['height']);

    if (x == null || y == null || width == null || height == null) {
      return false;
    }

    if (x < 0 || y < 0 || width <= 0 || height <= 0) {
      return false;
    }

    if (x + width > 1 || y + height > 1) {
      return false;
    }

    return true;
  }

  @override
  CorrectionVerdict checkSafety(CorrectionAction action) {
    if (!action.targetVerified) {
      return CorrectionVerdict.deniedUnverified;
    }

    if (!isTargetVerified(action.target)) {
      return CorrectionVerdict.deniedUnverified;
    }

    switch (action.actionType) {
      case CorrectionActionType.tap:
      case CorrectionActionType.longPress:
      case CorrectionActionType.swipe:
        return CorrectionVerdict.allowed;

      case CorrectionActionType.typeText:
      case CorrectionActionType.scroll:
      case CorrectionActionType.toggle:
      case CorrectionActionType.select:
      case CorrectionActionType.none:
      case CorrectionActionType.denied:
      case CorrectionActionType.unknown:
        return CorrectionVerdict.deniedSafety;
    }
  }

  @override
  Future<CorrectionVerdict> planAction({
    required ScreenTarget target,
    required CorrectionActionType actionType,
    String? textInput,
    String? swipeDirection,
  }) async {
    if (!isTargetVerified(target)) {
      return CorrectionVerdict.deniedUnverified;
    }

    switch (actionType) {
      case CorrectionActionType.tap:
      case CorrectionActionType.longPress:
        return CorrectionVerdict.allowed;

      case CorrectionActionType.swipe:
        if (!_validSwipeDirection(swipeDirection)) {
          return CorrectionVerdict.deniedSafety;
        }
        return CorrectionVerdict.allowed;

      default:
        return CorrectionVerdict.deniedSafety;
    }
  }

  @override
  Future<CorrectionAction> executeAction(
    CorrectionAction action,
  ) async {
    final safety = checkSafety(action);

    if (!safety.isAllowed) {
      return CorrectionAction.denied(
        actionId: action.actionId,
        target: action.target,
        reason: safety.name,
      );
    }

    // Native execution is intentionally not performed here yet.
    //
    // This service is the domain safety boundary. The repository below
    // owns SystemControlChannel actuation.
    return CorrectionAction(
      actionId: action.actionId,
      target: action.target,
      actionType: action.actionType,
      textInput: action.textInput,
      swipeDirection: action.swipeDirection,
      targetVerified: action.targetVerified,
      result: CorrectionResult.unknown,
      executedAt: DateTime.now(),
      locale: action.locale,
    );
  }

  @override
  Future<CorrectionResult> cancelAction(String actionId) async {
    // No native cancellation API currently exists.
    return CorrectionResult.denied;
  }

  bool _validSwipeDirection(String? direction) {
    if (direction == null) return false;

    switch (direction.trim().toLowerCase()) {
      case 'up':
      case 'down':
      case 'left':
      case 'right':
        return true;
      default:
        return false;
    }
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
