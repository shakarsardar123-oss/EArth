import '../../../../core/errors/result.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/screen_capture/screen_capture_service.dart';
import '../../../../core/screen_capture/screen_capture_result.dart';
import '../../../../core/screen_understanding/screen_understanding_result.dart';
import '../../../../core/screen_understanding/screen_understanding_service.dart';
import '../../domain/models/detection_result.dart';
import '../../domain/models/screen_target.dart';
import '../../domain/repositories/vision_repository.dart';

/// Adapts the real Screen Capture + Screen Understanding pipeline
/// to the Screen Target VisionRepository contract.
///
/// This class deliberately does NOT call VisionService directly.
/// ScreenUnderstandingEngine owns frame -> base64 -> vision -> parsing.
class ScreenUnderstandingVisionRepository implements VisionRepository {
  ScreenUnderstandingVisionRepository({
    required ScreenCaptureService screenCapture,
    required ScreenUnderstandingService screenUnderstanding,
  })  : _screenCapture = screenCapture,
        _screenUnderstanding = screenUnderstanding;

  final ScreenCaptureService _screenCapture;
  final ScreenUnderstandingService _screenUnderstanding;

  final Map<String, CapturedFrame> _frames = <String, CapturedFrame>{};

  @override
  bool get hasPermission => _screenCapture.state.canCaptureFrames;

  @override
  bool get isAvailable => _screenCapture.isSupported;

  @override
  Future<VisionResult> captureScreen(String screenId) async {
    if (screenId.trim().isEmpty) {
      return VisionResult.error;
    }

    if (!isAvailable) {
      return VisionResult.unavailable;
    }

    final result = await _screenCapture.captureSingleFrame();

    if (result.isSuccess) {
      final frame = result.valueOrNull;
      if (frame == null) {
        return VisionResult.error;
      }

      _frames[screenId] = frame;
      return VisionResult.success;
    }

    final failure = result.failureOrNull;
    if (failure?.phase == ScreenCapturePhase.requestProjection) {
      return VisionResult.deniedPermission;
    }

    return VisionResult.error;
  }

  @override
  Future<DetectionResult> analyzeScreen(String screenId) async {
    final normalizedScreenId = screenId.trim();

    if (normalizedScreenId.isEmpty) {
      return _failedResult(
        screenId: screenId,
        reason: 'empty_screen_id',
      );
    }

    if (!isAvailable) {
      return _failedResult(
        screenId: normalizedScreenId,
        reason: 'screen_capture_unavailable',
      );
    }

    var frame = _frames[normalizedScreenId];

    if (frame == null) {
      final captureResult = await _screenCapture.captureSingleFrame();

      if (!captureResult.isSuccess) {
        return _failedResult(
          screenId: normalizedScreenId,
          reason: captureResult.failureOrNull?.message ??
              'screen_capture_failed',
        );
      }

      frame = captureResult.valueOrNull;

      if (frame == null) {
        return _failedResult(
          screenId: normalizedScreenId,
          reason: 'empty_capture_result',
        );
      }

      _frames[normalizedScreenId] = frame;
    }

    final analysisResult = await _screenUnderstanding.analyzeFrame(frame);

    return analysisResult.fold(
      onSuccess: (representation) => _mapRepresentation(
        screenId: normalizedScreenId,
        representation: representation,
      ),
      onFailure: (failure) => _failedResult(
        screenId: normalizedScreenId,
        reason: failure.message,
      ),
    );
  }

  @override
  Future<ScreenTarget> verifyTarget(ScreenTarget target) async {
    // AI detections must never become verified merely because the
    // analysis succeeded. Fresh-frame verification remains a separate
    // safety boundary.
    return target.copyWith(verified: false);
  }

  DetectionResult _mapRepresentation({
    required String screenId,
    required ScreenRepresentation representation,
  }) {
    final targets = <ScreenTarget>[];

    for (var i = 0; i < representation.uiElements.length; i++) {
      final element = representation.uiElements[i];

      if (!_isValidBounds(element.boundingBox)) {
        continue;
      }

      targets.add(
        ScreenTarget(
          targetId: 'ui_${screenId}_$i',
          type: element.type.name,
          bounds: _boundsToMap(element.boundingBox),
          confidence: _safeConfidence(element.confidence),
          label: _cleanLabel(element.label),
          verified: false,
          locale: 'ku',
          detectedAt: _dateTimeFromEpoch(
            representation.metadata.timestamp,
          ),
          screenId: screenId,
        ),
      );
    }

    for (var i = 0; i < representation.textItems.length; i++) {
      final item = representation.textItems[i];

      if (item.text.trim().isEmpty ||
          !_isValidBounds(item.boundingBox)) {
        continue;
      }

      targets.add(
        ScreenTarget(
          targetId: 'text_${screenId}_$i',
          type: 'text',
          bounds: _boundsToMap(item.boundingBox),
          confidence: _safeConfidence(item.confidence),
          label: item.text.trim(),
          verified: false,
          locale: item.language ?? 'ku',
          detectedAt: _dateTimeFromEpoch(
            representation.metadata.timestamp,
          ),
          screenId: screenId,
        ),
      );
    }

    return DetectionResult(
      resultId:
          'screen_understanding_${screenId}_${representation.metadata.timestamp}',
      screenId: screenId,
      status: targets.isEmpty
          ? DetectionStatus.failed
          : DetectionStatus.completed,
      targets: List<ScreenTarget>.unmodifiable(targets),
      scanDurationMs: representation.metadata.processingTimeMs ?? 0,
      scannedAt: _dateTimeFromEpoch(
        representation.metadata.timestamp,
      ),
      locale: 'ku',
    );
  }

  DetectionResult _failedResult({
    required String screenId,
    required String reason,
  }) {
    return DetectionResult(
      resultId:
          'screen_understanding_failed_${screenId}_${DateTime.now().millisecondsSinceEpoch}',
      screenId: screenId,
      status: DetectionStatus.failed,
      targets: const <ScreenTarget>[],
      scanDurationMs: 0,
      scannedAt: DateTime.now(),
      locale: 'ku',
    );
  }

  bool _isValidBounds(TextBoundingBox box) {
    final values = <double>[
      box.x,
      box.y,
      box.width,
      box.height,
    ];

    if (values.any((value) => !value.isFinite)) {
      return false;
    }

    if (box.x < 0 ||
        box.y < 0 ||
        box.width <= 0 ||
        box.height <= 0) {
      return false;
    }

    if (box.right > 1 || box.bottom > 1) {
      return false;
    }

    // Reject the parser's full-screen fallback.
    if (box.x == 0 &&
        box.y == 0 &&
        box.width == 1 &&
        box.height == 1) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> _boundsToMap(TextBoundingBox box) {
    return <String, dynamic>{
      'x': box.x,
      'y': box.y,
      'width': box.width,
      'height': box.height,
    };
  }

  double _safeConfidence(double value) {
    if (!value.isFinite) return 0.0;
    if (value < 0) return 0.0;
    if (value > 1) return 1.0;
    return value;
  }

  String? _cleanLabel(String? value) {
    final label = value?.trim();
    return label == null || label.isEmpty ? null : label;
  }

  DateTime _dateTimeFromEpoch(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}
