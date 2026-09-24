/// stub_vision_repository.dart
/// AURA Assistant – Step 27: Screen Target
///
/// FAIL-CLOSED stub: all operations return denied/unavailable.
library;

import '../domain/models/detection_result.dart';
import '../domain/models/screen_target.dart';
import '../domain/repositories/vision_repository.dart';

class StubVisionRepository implements VisionRepository {
  @override
  bool get hasPermission => false;

  @override
  bool get isAvailable => false;

  @override
  Future<VisionResult> captureScreen(String screenId) async =>
      VisionResult.unavailable;

  @override
  Future<DetectionResult> analyzeScreen(String screenId) async =>
      DetectionResult.denied;

  @override
  Future<ScreenTarget> verifyTarget(ScreenTarget target) async =>
      target.copyWith(verified: false);
}
