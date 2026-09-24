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
    if (screenId.trim().isEmpty) {
      return DetectionVerdict.unknown;
    }

    if (!_visionRepository.isAvailable) {
      return DetectionVerdict.deniedUnavailable;
    }

    if (!_visionRepository.hasPermission) {
      return DetectionVerdict.deniedPermission;
    }

    if (!_detectionService.isAvailable) {
      return DetectionVerdict.deniedUnavailable;
    }

    if (!_detectionService.hasPermission) {
      return DetectionVerdict.deniedPermission;
    }

    final captureResult = await _visionRepository.captureScreen(screenId);

    switch (captureResult) {
      case VisionResult.success:
        break;
      case VisionResult.deniedPermission:
        return DetectionVerdict.deniedPermission;
      case VisionResult.unavailable:
        return DetectionVerdict.deniedUnavailable;
      case VisionResult.denied:
      case VisionResult.error:
      case VisionResult.unknown:
        return DetectionVerdict.denied;
    }

    final detectionResult =
        await _visionRepository.analyzeScreen(screenId);

    _detectionService.updateResult(detectionResult);

    if (!detectionResult.isUsable) {
      return DetectionVerdict.deniedUnavailable;
    }

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
    // FAIL-CLOSED: safety must pass before any native actuation.
    final safetyVerdict = _correctionService.checkSafety(action);
    if (safetyVerdict.isDenied) {
      return CorrectionAction.denied(
        actionId: action.actionId,
        target: action.target,
        reason: safetyVerdict.name,
      );
    }

    // FAIL-CLOSED: only verified/actionable targets may reach the
    // native screen-action repository.
    if (!_correctionService.isTargetVerified(action.target) ||
        !action.targetVerified ||
        !action.target.isActionable) {
      return CorrectionAction.denied(
        actionId: action.actionId,
        target: action.target,
        reason: 'target_not_verified',
      );
    }

    final ScreenActionResult result;

    switch (action.actionType) {
      case CorrectionActionType.tap:
        result = await _actionRepository.tap(action.target);
        break;

      case CorrectionActionType.longPress:
        result = await _actionRepository.longPress(action.target);
        break;

      case CorrectionActionType.swipe:
        result = await _actionRepository.swipe(
          target: action.target,
          direction: action.swipeDirection,
        );
        break;

      case CorrectionActionType.typeText:
        result = await _actionRepository.typeText(
          target: action.target,
          text: action.textInput,
        );
        break;

      case CorrectionActionType.scroll:
        result = await _actionRepository.scroll(
          target: action.target,
          direction: action.swipeDirection,
        );
        break;

      case CorrectionActionType.toggle:
      case CorrectionActionType.select:
      case CorrectionActionType.none:
      case CorrectionActionType.denied:
      case CorrectionActionType.unknown:
        return CorrectionAction.denied(
          actionId: action.actionId,
          target: action.target,
          reason: 'unsupported_action_type',
        );
    }

    final mappedResult = switch (result) {
      ScreenActionResult.success => CorrectionResult.success,
      ScreenActionResult.denied => CorrectionResult.denied,
      ScreenActionResult.deniedSafety => CorrectionResult.deniedSafety,
      ScreenActionResult.deniedUnverified => CorrectionResult.deniedUnverified,
      ScreenActionResult.deniedPermission => CorrectionResult.denied,
      ScreenActionResult.unavailable => CorrectionResult.failed,
      ScreenActionResult.error => CorrectionResult.failed,
      ScreenActionResult.unknown => CorrectionResult.unknown,
    };

    return CorrectionAction(
      actionId: action.actionId,
      target: action.target,
      actionType: action.actionType,
      textInput: action.textInput,
      swipeDirection: action.swipeDirection,
      targetVerified: action.targetVerified,
      result: mappedResult,
      executedAt: DateTime.now(),
      locale: action.locale,
    );
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
