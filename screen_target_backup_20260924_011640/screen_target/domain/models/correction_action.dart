/// correction_action.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Domain model for a correction action applied to a screen target.
/// FAIL-CLOSED: unverified → denied, unknown → denied.
library;

import 'package:meta/meta.dart';
import 'screen_target.dart';

/// Type of correction action.
enum CorrectionActionType {
  tap,
  longPress,
  swipe,
  typeText,
  scroll,
  toggle,
  select,
  none,
  denied,
  unknown,
  ;

  static CorrectionActionType fromName(String name) =>
      CorrectionActionType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => CorrectionActionType.unknown,
      );

  bool get isExecutable =>
      this != none && this != denied && this != unknown;
  bool get isDenied => this == denied || this == unknown;
}

/// Result of executing a correction action.
enum CorrectionResult {
  success,
  partial,
  failed,
  denied,
  deniedSafety,
  deniedUnverified,
  unknown,
  ;

  bool get isSuccess => this == success;
  bool get isDenied =>
      this == denied ||
      this == deniedSafety ||
      this == deniedUnverified ||
      this == unknown;
}

/// Immutable correction action.
@immutable
class CorrectionAction {
  /// Unique action identifier.
  final String actionId;

  /// Target screen target.
  final ScreenTarget target;

  /// Action type.
  final CorrectionActionType actionType;

  /// Text to type (if actionType == typeText).
  final String textInput;

  /// Swipe direction (if actionType == swipe).
  final String swipeDirection;

  /// Whether the target was verified before action execution.
  final bool targetVerified;

  /// Execution result.
  final CorrectionResult result;

  /// Execution timestamp.
  final DateTime executedAt;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  const CorrectionAction({
    required this.actionId,
    required this.target,
    this.actionType = CorrectionActionType.none,
    this.textInput = '',
    this.swipeDirection = '',
    this.targetVerified = false,
    this.result = CorrectionResult.unknown,
    required this.executedAt,
    this.locale = 'ku',
  });

  /// FAIL-CLOSED: factory for denied actions.
  factory CorrectionAction.denied({
    required String actionId,
    required ScreenTarget target,
    String? reason,
  }) =>
      CorrectionAction(
        actionId: actionId,
        target: target,
        actionType: CorrectionActionType.denied,
        targetVerified: false,
        result: CorrectionResult.denied,
        executedAt: DateTime.now(),
        locale: 'ku',
      );

  /// FAIL-CLOSED: unverified targets cannot have executable actions.
  bool get isExecutable =>
      actionType.isExecutable && targetVerified && target.isActionable;

  /// FAIL-CLOSED: unknown result → denied.
  bool get isDenied => result.isDenied;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CorrectionAction && actionId == other.actionId;

  @override
  int get hashCode => actionId.hashCode;

  @override
  String toString() =>
      'CorrectionAction(id: $actionId, type: $actionType, '
      'target: ${target.targetId}, result: $result)';
}
