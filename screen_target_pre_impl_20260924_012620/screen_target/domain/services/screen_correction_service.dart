/// screen_correction_service.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Domain service contract for screen target correction (action execution).
/// FAIL-CLOSED: unverified → denied, unknown → denied.
library;

import '../models/screen_target.dart';
import '../models/correction_action.dart';

/// Verdict for correction operations.
enum CorrectionVerdict {
  allowed,
  denied,
  deniedSafety,
  deniedUnverified,
  deniedPermission,
  deniedUnavailable,
  unknown,
  ;

  bool get isAllowed => this == allowed;
  bool get isDenied =>
      this == denied ||
      this == deniedSafety ||
      this == deniedUnverified ||
      this == deniedPermission ||
      this == deniedUnavailable ||
      this == unknown;
}

/// Abstract domain service for screen target correction.
/// Must be implemented by infrastructure adapters.
abstract class ScreenCorrectionService {
  /// Plan a correction action for a target.
  /// FAIL-CLOSED: unverified targets → denied.
  Future<CorrectionVerdict> planAction({
    required ScreenTarget target,
    required CorrectionActionType actionType,
    String? textInput,
    String? swipeDirection,
  });

  /// Execute a correction action.
  /// FAIL-CLOSED: unverified/unknown → denied.
  Future<CorrectionAction> executeAction(CorrectionAction action);

  /// Cancel a pending action.
  Future<CorrectionResult> cancelAction(String actionId);

  /// Check if an action is safe to execute.
  /// FAIL-CLOSED: unknown → denied.
  CorrectionVerdict checkSafety(CorrectionAction action);

  /// Check if the target is verified before action.
  bool isTargetVerified(ScreenTarget target);
}
