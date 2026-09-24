/// vision_repository.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Domain repository contract for vision/screen analysis.
/// FAIL-CLOSED: any error → deny, unavailable → deny.
library;

import '../models/screen_target.dart';
import '../models/detection_result.dart';

/// Result of a vision operation.
enum VisionResult {
  success,
  denied,
  deniedPermission,
  unavailable,
  error,
  unknown,
  ;

  bool get isSuccess => this == success;
  bool get isDenied =>
      this == denied ||
      this == deniedPermission ||
      this == unavailable ||
      this == error ||
      this == unknown;
}

/// Abstract repository for vision/screen analysis.
/// Infrastructure adapters must implement this interface EXACTLY.
abstract class VisionRepository {
  /// Capture the current screen.
  /// FAIL-CLOSED: denied/unknown → denied.
  Future<VisionResult> captureScreen(String screenId);

  /// Analyze captured screen for targets.
  /// FAIL-CLOSED: any failure → empty result.
  Future<DetectionResult> analyzeScreen(String screenId);

  /// Verify a detected target using accessibility tree.
  /// FAIL-CLOSED: unverified → target stays unverified.
  Future<ScreenTarget> verifyTarget(ScreenTarget target);

  /// Check if screen capture permission is granted.
  bool get hasPermission;

  /// Check if vision/screen analysis is available.
  bool get isAvailable;
}
