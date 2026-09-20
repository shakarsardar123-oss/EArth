/// screen_understanding_engine.dart
///
/// Abstraction for analyzing captured frames into structured representations.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/action_verifier_test.dart`.
library;

import 'screen_capture_service.dart';

/// Feature-local axis-aligned rectangle with integer coordinates.
///
/// The core layer has its own representation without `Rect`. R3 adapters
/// will map between them.
class Rect {
  const Rect.fromLTWH(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;

  /// Center point as `(left + width / 2, top + height / 2)`.
  /// Returns doubles because center may not land on a pixel boundary.
  (double, double) get center => (left + width / 2.0, top + height / 2.0);

  @override
  String toString() => 'Rect.fromLTWH($left, $top, $width, $height)';
}

/// A text item detected on the screen.
class ScreenTextItem {
  const ScreenTextItem({
    required this.text,
    required this.bounds,
    required this.confidence,
  });

  /// Recognized text.
  final String text;

  /// Bounding box of the text.
  final Rect bounds;

  /// Confidence of the OCR/text detection.
  final double confidence;
}

/// Structured understanding of a captured screen.
///
/// Feature-local type; the core layer has its own `ScreenRepresentation`
/// with `metadata, textItems, uiElements, regions`. R3 adapters will map
/// between them.
class ScreenRepresentation {
  const ScreenRepresentation({
    required this.elements,
    required this.textItems,
    required this.regions,
    required this.timestamp,
    required this.overallConfidence,
  });

  /// Generic UI elements detected (buttons, inputs, images, etc.).
  final List<dynamic> elements;

  /// Text items found on the screen.
  final List<ScreenTextItem> textItems;

  /// Semantic regions of the screen.
  final List<dynamic> regions;

  /// When the analysis was performed.
  final DateTime timestamp;

  /// Overall confidence of the understanding pass.
  final double overallConfidence;
}

/// Contract for turning a [CapturedFrame] into a [ScreenRepresentation].
///
/// Implementations must be fail-closed: if analysis fails they should throw
/// rather than return a synthetic result.
abstract class ScreenUnderstandingEngine {
  /// Analyze the captured frame and return a structured representation.
  ///
  /// Throws on failure; callers wrap in try/catch.
  Future<ScreenRepresentation> analyze(CapturedFrame frame);
}
