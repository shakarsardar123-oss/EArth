/// screen_detection_service.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Domain service contract for screen detection.
/// FAIL-CLOSED: any error → empty result, unverified targets → not actionable.
library;

import '../models/screen_target.dart';
import '../models/detection_result.dart';

/// Verdict for detection operations.
enum DetectionVerdict {
  allowed,
  denied,
  deniedPermission,
  deniedSafety,
  deniedUnavailable,
  unknown,
  ;

  bool get isAllowed => this == allowed;
  bool get isDenied =>
      this == denied ||
      this == deniedPermission ||
      this == deniedSafety ||
      this == deniedUnavailable ||
      this == unknown;
}

/// Abstract domain service for screen target detection.
/// Must be implemented by infrastructure adapters.
abstract class ScreenDetectionService {
  /// Scan the current screen for targets.
  /// FAIL-CLOSED: any failure → empty result.
  Future<DetectionVerdict> scanScreen({
    required String screenId,
    bool verifyTargets = true,
  });

  /// Get the latest detection result for a screen.
  /// FAIL-CLOSED: unknown → empty result.
  Future<DetectionResult> getLatestResult(String screenId);

  /// Verify a detected target (second-pass confirmation).
  /// FAIL-CLOSED: unverified → target remains unverified.
  Future<ScreenTarget> verifyTarget(ScreenTarget target);

  /// Find a target by label/text.
  /// FAIL-CLOSED: not found → invalid target.
  Future<ScreenTarget> findByLabel({
    required String screenId,
    required String label,
  });

  /// Check if screen capture permission is granted.
  bool get hasPermission;

  /// Check if screen detection is available on this device.
  bool get isAvailable;
}
