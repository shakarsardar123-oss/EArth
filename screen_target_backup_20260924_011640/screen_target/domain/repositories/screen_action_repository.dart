/// screen_action_repository.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Domain repository contract for executing screen actions.
/// FAIL-CLOSED: unverified → denied, unknown → denied.
library;

import '../models/screen_target.dart';

/// Result of a screen action operation.
enum ScreenActionResult {
  success,
  denied,
  deniedSafety,
  deniedUnverified,
  deniedPermission,
  unavailable,
  error,
  unknown,
  ;

  bool get isSuccess => this == success;
  bool get isDenied =>
      this == denied ||
      this == deniedSafety ||
      this == deniedUnverified ||
      this == deniedPermission ||
      this == unavailable ||
      this == error ||
      this == unknown;
}

/// Abstract repository for executing screen actions.
/// Infrastructure adapters must implement this interface EXACTLY.
abstract class ScreenActionRepository {
  /// Execute a tap on a target.
  /// FAIL-CLOSED: unverified → denied.
  Future<ScreenActionResult> tap(ScreenTarget target);

  /// Execute a long press on a target.
  /// FAIL-CLOSED: unverified → denied.
  Future<ScreenActionResult> longPress(ScreenTarget target);

  /// Execute a swipe on a target.
  /// FAIL-CLOSED: unverified → denied.
  Future<ScreenActionResult> swipe({
    required ScreenTarget target,
    required String direction,
  });

  /// Type text into a target input field.
  /// FAIL-CLOSED: unverified → denied.
  Future<ScreenActionResult> typeText({
    required ScreenTarget target,
    required String text,
  });

  /// Scroll a target.
  /// FAIL-CLOSED: unverified → denied.
  Future<ScreenActionResult> scroll({
    required ScreenTarget target,
    required String direction,
  });

  /// Check if action execution permission is granted.
  bool get hasPermission;

  /// Check if screen action execution is available.
  bool get isAvailable;
}
