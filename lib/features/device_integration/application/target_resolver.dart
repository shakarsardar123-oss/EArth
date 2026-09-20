/// target_resolver.dart
///
/// Resolves a textual target query into a [NormalizedPoint] by capturing the
/// screen, analyzing it, and searching for the target.
///
/// RECOVERED in P1-RECOVERY step R2 from the behaviour pinned by
/// `test/features/device_integration/target_resolver_test.dart`.
library;

import '../domain/entities/device_action.dart';
import '../domain/models/device_integration_failure.dart';
import '../infrastructure/services/screen_capture_service.dart';
import '../infrastructure/services/screen_understanding_engine.dart';
import '../infrastructure/services/screen_search_service.dart';
import '../../../core/errors/result.dart';

/// Resolves a textual target description to a [NormalizedPoint] on the screen.
///
/// Pipeline: capture → analyze → search → select highest-confidence target
/// → normalize center to [0, 1]².
class TargetResolver {
  TargetResolver({
    required this.screenCapture,
    required this.screenUnderstanding,
    required this.screenSearch,
    this.confidenceThreshold = 0.5,
  });

  final ScreenCaptureService screenCapture;
  final ScreenUnderstandingEngine screenUnderstanding;
  final ScreenSearchService screenSearch;

  /// Minimum confidence a [DetectedTarget] must have to be accepted.
  final double confidenceThreshold;

  /// Resolve a single target query to a [NormalizedPoint].
  ///
  /// Returns a failure in the [DeviceIntegrationFailurePhase.targetResolution]
  /// phase if any step fails or no adequate target is found.
  Future<Result<NormalizedPoint, DeviceIntegrationFailure>> resolve(
      String queryText) async {
    try {
      // 1. Capture
      final frame = await screenCapture.capture();

      // 2. Analyze
      await screenUnderstanding.analyze(frame);

      // 3. Search
      final targets = await screenSearch.search(TargetQuery(label: queryText));

      // 4. No targets
      if (targets.isEmpty) {
        return Result.failure(
          DeviceIntegrationFailure.targetResolution(
            'No targets found for query: $queryText',
          ),
        );
      }

      // 5. Select highest-confidence target
      final best = targets.reduce(
          (a, b) => a.confidence >= b.confidence ? a : b);

      // 6. Check confidence threshold
      if (best.confidence < confidenceThreshold) {
        return Result.failure(
          DeviceIntegrationFailure.targetResolution(
            'Target confidence ${best.confidence} below threshold $confidenceThreshold',
          ),
        );
      }

      // 7. Normalize center to [0, 1]²
      final (cx, cy) = best.bounds.center;
      return Result.success(
        NormalizedPoint(
          x: cx / frame.width,
          y: cy / frame.height,
        ),
      );
    } on DeviceIntegrationFailure {
      rethrow;
    } catch (e) {
      return Result.failure(
        DeviceIntegrationFailure.targetResolution(
          'Target resolution failed: $e',
          cause: e is DeviceIntegrationFailure ? e : null,
        ),
      );
    }
  }

  /// Resolve multiple target queries.
  ///
  /// Returns a list of [NormalizedPoint]s in the same order as
  /// [queryTexts]. Fails if any single query fails.
  Future<Result<List<NormalizedPoint>, DeviceIntegrationFailure>> resolveAll(
      List<String> queryTexts) async {
    final points = <NormalizedPoint>[];
    for (final q in queryTexts) {
      final result = await resolve(q);
      if (result.isFailure) {
        return Result.failure(result.failureOrNull!);
      }
      points.add(result.valueOrNull!);
    }
    return Result.success(points);
  }
}
