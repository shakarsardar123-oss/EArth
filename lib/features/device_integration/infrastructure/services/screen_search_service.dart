/// screen_search_service.dart
///
/// Abstraction for searching a screen representation for targets.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/target_resolver_test.dart` and
/// `test/features/device_integration/action_verifier_test.dart`.
library;

import 'screen_understanding_engine.dart';

/// A target detected on the screen by the search service.
class DetectedTarget {
  const DetectedTarget({
    required this.label,
    required this.bounds,
    required this.confidence,
    required this.category,
    required this.metadata,
  });

  /// Human-readable label of the detected target.
  final String label;

  /// Bounding box of the target on screen.
  final Rect bounds;

  /// Confidence score [0, 1].
  final double confidence;

  /// Category of the target (button, input, dialog, etc.).
  final String category;

  /// Extra metadata from the detection.
  final Map<String, dynamic> metadata;
}

/// A query describing what to search for on the screen.
class TargetQuery {
  const TargetQuery({
    required this.label,
    this.category,
    this.metadata,
  });

  /// Text label to search for.
  final String label;

  /// Optional category filter.
  final String? category;

  /// Optional metadata filter.
  final Map<String, dynamic>? metadata;
}

/// Contract for searching screen representations for targets.
///
/// Implementations must be fail-closed: if search fails they should throw
/// rather than return a synthetic result.
abstract class ScreenSearchService {
  /// Search the current screen for targets matching [query].
  ///
  /// Throws on failure; callers wrap in try/catch.
  Future<List<DetectedTarget>> search(TargetQuery query);
}
