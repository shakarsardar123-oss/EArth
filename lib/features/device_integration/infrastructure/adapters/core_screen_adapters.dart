/// core_screen_adapters.dart
///
/// Bridges the `core/` screen-capture / screen-understanding / screen-search
/// subsystems (which return `Result<T, Failure>` and use their own model
/// types) to the feature-local abstractions in
/// `device_integration/infrastructure/services/` (which throw on failure
/// and use simpler feature-local model types).
///
/// The understanding and search adapters share a small mutable
/// [_LatestScreenState] so that `search()` — which, per the feature-local
/// interface, takes no representation argument — can operate on the
/// representation most recently produced by `analyze()`.
library;

import 'dart:typed_data';

import '../services/screen_capture_service.dart' as feature_capture;
import '../services/screen_understanding_engine.dart' as feature_understanding;
import '../services/screen_search_service.dart' as feature_search;

import '../../../../core/screen_capture/screen_capture_service.dart'
    as core_capture_service;
import '../../../../core/screen_capture/screen_capture_result.dart'
    as core_capture_result;
import '../../../../core/screen_understanding/screen_understanding_service.dart'
    as core_understanding_service;
import '../../../../core/screen_understanding/screen_understanding_result.dart'
    as core_understanding_result;
import '../../../../core/screen_search/search_service.dart'
    as core_search_service;
import '../../../../core/screen_search/search_result.dart' as core_search_result;

/// Mutable holder for the most recent core [ScreenRepresentation] and the
/// pixel dimensions of the frame it was produced from (needed to
/// denormalize the 0.0–1.0 bounding boxes core produces into the
/// pixel-based [feature_understanding.Rect] the feature layer expects).
class _LatestScreenState {
  core_understanding_result.ScreenRepresentation? representation;
  int frameWidth = 1;
  int frameHeight = 1;
}

feature_understanding.Rect _denormalize(
  core_understanding_result.TextBoundingBox box,
  int frameWidth,
  int frameHeight,
) {
  return feature_understanding.Rect.fromLTWH(
    (box.x * frameWidth).round(),
    (box.y * frameHeight).round(),
    (box.width * frameWidth).round(),
    (box.height * frameHeight).round(),
  );
}

/// Adapts core's [ScreenCaptureService] (Result-returning) to the
/// feature-local [feature_capture.ScreenCaptureService] (throwing).
class CoreScreenCaptureAdapter implements feature_capture.ScreenCaptureService {
  CoreScreenCaptureAdapter(this._core);

  final core_capture_service.ScreenCaptureService _core;

  @override
  Future<feature_capture.CapturedFrame> capture() async {
    final result = await _core.captureSingleFrame();
    return result.fold<feature_capture.CapturedFrame>(
      onSuccess: (frame) => feature_capture.CapturedFrame(
        imageBytes: Uint8List.fromList(frame.bytes.toList()),
        width: frame.width,
        height: frame.height,
        timestamp: DateTime.fromMillisecondsSinceEpoch(frame.timestamp),
      ),
      onFailure: (failure) =>
          throw StateError('Screen capture failed: ${failure.message}'),
    );
  }
}

/// Adapts core's [ScreenUnderstandingService] to the feature-local
/// [feature_understanding.ScreenUnderstandingEngine].
///
/// On success, records the core representation (and frame dimensions) in
/// the shared [_LatestScreenState] so [CoreScreenSearchAdapter] can use it.
class CoreScreenUnderstandingAdapter
    implements feature_understanding.ScreenUnderstandingEngine {
  CoreScreenUnderstandingAdapter(this._core, this._sharedState);

  final core_understanding_service.ScreenUnderstandingService _core;
  final _LatestScreenState _sharedState;

  @override
  Future<feature_understanding.ScreenRepresentation> analyze(
    feature_capture.CapturedFrame frame,
  ) async {
    final coreFrame = core_capture_result.CapturedFrame(
      bytes: core_capture_result.Uint8ListSafe(frame.imageBytes.toList()),
      width: frame.width,
      height: frame.height,
      timestamp: frame.timestamp.millisecondsSinceEpoch,
    );

    final result = await _core.analyzeFrame(coreFrame);

    return result.fold<feature_understanding.ScreenRepresentation>(
      onSuccess: (repr) {
        _sharedState.representation = repr;
        _sharedState.frameWidth = repr.metadata.width;
        _sharedState.frameHeight = repr.metadata.height;

        final textItems = repr.textItems
            .map(
              (t) => feature_understanding.ScreenTextItem(
                text: t.text,
                bounds: _denormalize(
                  t.boundingBox,
                  repr.metadata.width,
                  repr.metadata.height,
                ),
                confidence: t.confidence,
              ),
            )
            .toList();

        return feature_understanding.ScreenRepresentation(
          elements: const [],
          textItems: textItems,
          regions: const [],
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(repr.metadata.timestamp),
          overallConfidence: repr.metadata.overallConfidence,
        );
      },
      onFailure: (failure) =>
          throw StateError('Screen understanding failed: ${failure.message}'),
    );
  }
}

/// Adapts core's [ScreenSearchService] to the feature-local
/// [feature_search.ScreenSearchService].
///
/// The feature-local interface's `search(query)` takes no representation,
/// so this reads the representation most recently cached by
/// [CoreScreenUnderstandingAdapter] via the shared [_LatestScreenState].
class CoreScreenSearchAdapter implements feature_search.ScreenSearchService {
  CoreScreenSearchAdapter(this._core, this._sharedState);

  final core_search_service.ScreenSearchService _core;
  final _LatestScreenState _sharedState;

  @override
  Future<List<feature_search.DetectedTarget>> search(
    feature_search.TargetQuery query,
  ) async {
    final representation = _sharedState.representation;
    if (representation == null) {
      throw StateError(
        'No screen representation available — call analyze() before search().',
      );
    }

    final coreQuery = core_search_result.SearchQuery(
      targetType: core_search_result.SearchTargetType.text,
      query: query.label,
    );

    final result = await _core.search(coreQuery, representation);

    return result.fold<List<feature_search.DetectedTarget>>(
      onSuccess: (results) => results.results.map((r) {
        return feature_search.DetectedTarget(
          label: r.matchedText?.text ??
              r.matchedElement?.label ??
              r.matchedRegion?.type.name ??
              query.label,
          bounds: _denormalize(
            r.boundingBox,
            _sharedState.frameWidth,
            _sharedState.frameHeight,
          ),
          confidence: r.confidence,
          category: r.targetType.name,
          metadata: const {},
        );
      }).toList(),
      onFailure: (failure) =>
          throw StateError('Screen search failed: ${failure.message}'),
    );
  }
}

/// The three feature-local-shaped services, backed by core implementations.
class CoreScreenAdapterBundle {
  const CoreScreenAdapterBundle({
    required this.capture,
    required this.understanding,
    required this.search,
  });

  final feature_capture.ScreenCaptureService capture;
  final feature_understanding.ScreenUnderstandingEngine understanding;
  final feature_search.ScreenSearchService search;
}

/// Builds a [CoreScreenAdapterBundle] wrapping the given core services.
///
/// The understanding and search adapters share one [_LatestScreenState]
/// instance, so calls made through this bundle must call `analyze()`
/// before `search()`, matching [TargetResolver]'s usage pattern.
CoreScreenAdapterBundle buildCoreScreenAdapterBundle({
  required core_capture_service.ScreenCaptureService captureService,
  required core_understanding_service.ScreenUnderstandingService
      understandingService,
  required core_search_service.ScreenSearchService searchService,
}) {
  final sharedState = _LatestScreenState();
  return CoreScreenAdapterBundle(
    capture: CoreScreenCaptureAdapter(captureService),
    understanding:
        CoreScreenUnderstandingAdapter(understandingService, sharedState),
    search: CoreScreenSearchAdapter(searchService, sharedState),
  );
}
