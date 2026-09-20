import 'vision_target.dart';
import '../../../core/errors/result.dart';

/// Result of an AI vision analysis operation.
///
/// Contains the textual description, detected targets, and optional metadata.
class VisionResult {
  const VisionResult({
    required this.description,
    this.targets = const [],
    this.sceneDescription,
    this.ocrText,
    this.objects = const [],
    this.rawResponse,
    this.processingTimeMs,
    this.modelUsed,
    this.imageSize,
    this.timestamp,
    this.isSuccess = true,
    this.errorMessage,
  });

  /// Primary textual description / answer from the AI.
  final String description;

  /// All detected targets (objects, text regions, people, etc.).
  final List<VisionTarget> targets;

  /// High-level scene description.
  final String? sceneDescription;

  /// Extracted text (OCR), if any.
  final String? ocrText;

  /// List of object labels (convenience shortcut).
  final List<String> objects;

  /// Raw API response for debugging.
  final Map<String, dynamic>? rawResponse;

  /// Processing time in milliseconds.
  final int? processingTimeMs;

  /// Model used for the analysis (e.g. 'gpt-4o').
  final String? modelUsed;

  /// Size of the input image (width, height).
  final ({int width, int height})? imageSize;

  /// Timestamp of the analysis.
  final DateTime? timestamp;

  /// Whether the analysis succeeded.
  final bool isSuccess;

  /// Error message if the analysis failed.
  final String? errorMessage;

  /// Create a failure result.
  factory VisionResult.failure(String errorMessage) => VisionResult(
        description: '',
        isSuccess: false,
        errorMessage: errorMessage,
      );

  /// Create from parsed AI response.
  factory VisionResult.fromAnalysis({
    required String description,
    List<VisionTarget> targets = const [],
    String? sceneDescription,
    String? ocrText,
    Map<String, dynamic>? rawResponse,
    int? processingTimeMs,
    String? modelUsed,
  }) =>
      VisionResult(
        description: description,
        targets: targets,
        sceneDescription: sceneDescription,
        ocrText: ocrText,
        objects: targets
            .where((t) => t.type == VisionTargetType.object)
            .map((t) => t.label)
            .toList(),
        rawResponse: rawResponse,
        processingTimeMs: processingTimeMs,
        modelUsed: modelUsed,
        timestamp: DateTime.now(),
      );

  /// Convert to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'description': description,
        'targets': targets.map((t) => t.toJson()).toList(),
        'scene_description': sceneDescription,
        'ocr_text': ocrText,
        'objects': objects,
        'processing_time_ms': processingTimeMs,
        'model_used': modelUsed,
        'is_success': isSuccess,
        'error_message': errorMessage,
      };

  @override
  String toString() =>
      'VisionResult(success: $isSuccess, targets: ${targets.length}, desc: ${description.substring(0, description.length > 60 ? 60 : description.length)}...)';
}
