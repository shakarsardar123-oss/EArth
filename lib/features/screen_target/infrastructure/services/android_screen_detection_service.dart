import '../../domain/models/screen_target.dart';
import '../../domain/models/detection_result.dart';
import '../../domain/services/screen_detection_service.dart';

/// Conservative screen-target detection adapter.
///
/// This service accepts only targets that have:
/// - a real normalized bounding box
/// - finite coordinates
/// - bounds inside the screen
/// - confidence >= 0.70
/// - verified == true when verification is requested
///
/// It deliberately does not manufacture coordinates for incomplete
/// vision results.
class AndroidScreenDetectionService implements ScreenDetectionService {
  final Map<String, DetectionResult> _latestResults = {};

  const AndroidScreenDetectionService();

  @override
  bool get hasPermission => true;

  @override
  bool get isAvailable => true;

  @override
  Future<DetectionVerdict> scanScreen({
    required String screenId,
    bool verifyTargets = true,
  }) async {
    if (screenId.trim().isEmpty) {
      return DetectionVerdict.unknown;
    }

    final result = _latestResults[screenId];

    if (result == null) {
      return DetectionVerdict.deniedUnavailable;
    }

    if (!result.isUsable) {
      return DetectionVerdict.deniedUnavailable;
    }

    final usableTargets = result.targets.where(
      (target) => _isValidTarget(
        target,
        requireVerified: verifyTargets,
      ),
    );

    if (usableTargets.isEmpty) {
      return DetectionVerdict.deniedSafety;
    }

    return DetectionVerdict.allowed;
  }

  @override
  Future<DetectionResult> getLatestResult(String screenId) async {
    final result = _latestResults[screenId];

    if (result != null) {
      return result;
    }

    return DetectionResult.unknown(
      resultId: 'unknown-$screenId',
      screenId: screenId,
    );
  }

  @override
  Future<ScreenTarget> verifyTarget(ScreenTarget target) async {
    if (!_isValidTarget(target, requireVerified: false)) {
      return target.copyWith(
        verified: false,
      );
    }

    // This layer does not invent a second vision result.
    //
    // A future verification implementation must compare the target
    // against a fresh captured/analyzed frame before setting verified=true.
    //
    // Therefore an unverified target stays unverified here.
    return target.copyWith(
      verified: false,
    );
  }

  @override
  Future<ScreenTarget> findByLabel({
    required String screenId,
    required String label,
  }) async {
    if (screenId.trim().isEmpty || label.trim().isEmpty) {
      return _deniedTarget(
        screenId: screenId,
        label: label,
      );
    }

    final result = _latestResults[screenId];

    if (result == null || !result.isUsable) {
      return _deniedTarget(
        screenId: screenId,
        label: label,
      );
    }

    final wanted = label.trim().toLowerCase();

    for (final target in result.targets) {
      if (!_isValidTarget(target, requireVerified: true)) {
        continue;
      }

      final targetLabel = target.label.trim().toLowerCase();

      if (targetLabel == wanted) {
        return target;
      }
    }

    return _deniedTarget(
      screenId: screenId,
      label: label,
    );
  }

  /// Internal ingestion point for a real screen-understanding result.
  ///
  /// Invalid/full-screen fallback targets are filtered before storage.
  void updateResult(DetectionResult result) {
    final filteredTargets = result.targets
        .where(
          (target) => _isValidTarget(
            target,
            requireVerified: false,
          ),
        )
        .toList(growable: false);

    _latestResults[result.screenId] = DetectionResult(
      resultId: result.resultId,
      screenId: result.screenId,
      status: filteredTargets.isEmpty
          ? DetectionStatus.failed
          : result.status,
      targets: filteredTargets,
      scanDurationMs: result.scanDurationMs,
      scannedAt: result.scannedAt,
      locale: result.locale,
    );
  }

  bool _isValidTarget(
    ScreenTarget target, {
    required bool requireVerified,
  }) {
    if (target.targetId.trim().isEmpty) {
      return false;
    }

    if (target.label.trim().isEmpty) {
      return false;
    }

    if (target.confidence < 0.70) {
      return false;
    }

    if (requireVerified && !target.verified) {
      return false;
    }

    final bounds = target.bounds;

    if (bounds == null) {
      return false;
    }

    final x = _number(bounds['x']);
    final y = _number(bounds['y']);
    final width = _number(bounds['width']);
    final height = _number(bounds['height']);

    if (x == null || y == null || width == null || height == null) {
      return false;
    }

    if (![x, y, width, height].every(double.isFinite)) {
      return false;
    }

    if (x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1 ||
        y + height > 1) {
      return false;
    }

    // Explicitly reject the dangerous "entire screen" fallback.
    if (x == 0 &&
        y == 0 &&
        width == 1 &&
        height == 1) {
      return false;
    }

    return true;
  }

  ScreenTarget _deniedTarget({
    required String screenId,
    required String label,
  }) {
    return ScreenTarget(
      targetId: 'denied-${DateTime.now().microsecondsSinceEpoch}',
      type: 'unknown',
      bounds: null,
      confidence: 0,
      label: label,
      verified: false,
      locale: 'ku',
      detectedAt: DateTime.now(),
      screenId: screenId,
    );
  }

  double? _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value');
  }
}
