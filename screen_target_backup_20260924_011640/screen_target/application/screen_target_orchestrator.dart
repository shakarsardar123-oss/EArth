/// screen_target_orchestrator.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Orchestrates ScreenDetectionService + ScreenCorrectionService +
/// VisionRepository + ScreenActionRepository.
/// FAIL-CLOSED: unverified → deny, unknown → deny.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/correction_action.dart';
import '../domain/models/detection_result.dart';
import '../domain/models/screen_target.dart';
import '../domain/repositories/screen_action_repository.dart';
import '../domain/repositories/vision_repository.dart';
import '../domain/services/screen_correction_service.dart';
import '../domain/services/screen_detection_service.dart';
import 'providers.dart';

class ScreenTargetOrchestrator {
  final ScreenDetectionService _detectionService;
  final ScreenCorrectionService _correctionService;
  final VisionRepository _visionRepository;
  final ScreenActionRepository _actionRepository;

  ScreenTargetOrchestrator({
    required ScreenDetectionService detectionService,
    required ScreenCorrectionService correctionService,
    required VisionRepository visionRepository,
    required ScreenActionRepository actionRepository,
  })  : _detectionService = detectionService,
        _correctionService = correctionService,
        _visionRepository = visionRepository,
        _actionRepository = actionRepository;

  /// Scan screen for targets.
  /// FAIL-CLOSED: permission denied or unavailable → deny.
  Future<DetectionVerdict> scanScreen({
    required String screenId,
    bool verifyTargets = true,
  }) async {
    if (!_visionRepository.isAvailable) return DetectionVerdict.denied;
    if (!_visionRepository.hasPermission) return DetectionVerdict.denied;
    if (!_detectionService.isAvailable) return DetectionVerdict.denied;
    if (!_detectionService.hasPermission) return DetectionVerdict.denied;
    return _detectionService.scanScreen(
      screenId: screenId,
      verifyTargets: verifyTargets,
    );
  }

  /// Get latest detection result for a screen.
  Future<DetectionResult> getLatestResult(String screenId) async {
    return _detectionService.getLatestResult(screenId);
  }

  /// Plan a correction action.
  /// FAIL-CLOSED: unverified target → deny.
  Future<CorrectionVerdict> planAction({
    required ScreenTarget target,
    required CorrectionActionType actionType,
    String? textInput,
    String? swipeDirection,
  }) async {
    if (!_correctionService.isTargetVerified(target)) {
      return CorrectionVerdict.denied;
    }
    return _correctionService.planAction(
      target: target,
      actionType: actionType,
      textInput: textInput,
      swipeDirection: swipeDirection,
    );
  }

  /// Execute a correction action.
  /// FAIL-CLOSED: safety check fails → deny.
  Future<CorrectionAction> executeAction(CorrectionAction action) async {
    final safetyVerdict = _correctionService.checkSafety(action);
    if (safetyVerdict.isDenied) {
      return CorrectionAction.denied;
    }
    return _correctionService.executeAction(action);
  }

  /// Find a target by label.
  Future<ScreenTarget> findByLabel({
    required String screenId,
    required String label,
  }) async {
    return _detectionService.findByLabel(screenId: screenId, label: label);
  }
}

final screenTargetOrchestratorProvider = Provider<ScreenTargetOrchestrator>((ref) {
  return ScreenTargetOrchestrator(
    detectionService: ref.watch(screenDetectionServiceProvider),
    correctionService: ref.watch(screenCorrectionServiceProvider),
    visionRepository: ref.watch(visionRepositoryProvider),
    actionRepository: ref.watch(screenActionRepositoryProvider),
  );
});
