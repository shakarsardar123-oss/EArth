import '../../domain/entities/vision/vision_entities.dart';

/// Abstraction for AI vision analysis services.
///
/// Implementations use multimodal LLMs (e.g. gpt-4o vision) to analyze
/// images for objects, scenes, text, and target location.
abstract class VisionService {
  /// Whether the vision service is available and configured.
  Future<bool> isAvailable();

  /// Analyze an image and return a comprehensive description.
  ///
  /// [imageBase64] — base64-encoded JPEG/PNG image data (no data: prefix).
  /// [prompt] — Optional text prompt guiding the analysis.
  Future<VisionResult> analyzeImage({
    required String imageBase64,
    String? prompt,
  });

  /// Find a specific object in the image and return its location.
  ///
  /// [imageBase64] — base64-encoded image data.
  /// [objectName] — Name/description of the object to find.
  Future<VisionResult> findObject({
    required String imageBase64,
    required String objectName,
  });

  /// Read/extract text from the image (OCR via vision model).
  ///
  /// [imageBase64] — base64-encoded image data.
  /// [language] — Optional language hint for OCR (e.g. 'ku' for Kurdish).
  Future<VisionResult> readText({
    required String imageBase64,
    String? language,
  });

  /// Describe the overall scene in the image.
  ///
  /// [imageBase64] — base64-encoded image data.
  Future<VisionResult> describeScene({
    required String imageBase64,
  });

  /// Locate a specific target in the image and return its position
  /// with bounding box coordinates suitable for overlay rendering.
  ///
  /// [imageBase64] — base64-encoded image data.
  /// [targetDescription] — Description of what to locate.
  /// [overlayStyle] — Preferred overlay style (rect, circle, arrow, point).
  Future<VisionResult> locateTarget({
    required String imageBase64,
    required String targetDescription,
    String overlayStyle = 'rect',
  });

  /// Shut down the service and release resources.
  Future<void> dispose();
}
