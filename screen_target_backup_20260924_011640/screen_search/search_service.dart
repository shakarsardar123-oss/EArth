/// Abstract interface for the AURA screen-search / target-detection subsystem.
///
/// Takes a [SearchQuery] and a [ScreenRepresentation] and returns
/// ranked [SearchResults] matching the query. Read-only on
/// [ScreenRepresentation] — no new vision calls or device actions.
library;

import 'dart:async';

import '../errors/failures.dart';
import '../errors/result.dart';
import '../screen_understanding/screen_understanding_result.dart';
import 'search_result.dart';
import 'search_state.dart';

/// Contract for the screen-search subsystem.
///
/// Implementations search an existing [ScreenRepresentation] for
/// targets (text, UI elements, semantic labels, regions) and
/// return ranked structured results with bounding boxes,
/// confidence, and matching reasons.
abstract class ScreenSearchService {
  /// Search the given [representation] for targets matching [query].
  ///
  /// Returns [Result.success] with [SearchResults] on success,
  /// or [Result.failure] with [ScreenSearchFailure] on error.
  ///
  /// The [representation] must not be null; if no representation
  /// is available, return a [ScreenSearchFailure] with phase
  /// [ScreenSearchPhase.noRepresentation].
  Future<Result<SearchResults, ScreenSearchFailure>> search(
    SearchQuery query,
    ScreenRepresentation representation,
  );

  /// Cancel any in-progress search.
  ///
  /// After cancellation, [state.status] will be
  /// [ScreenSearchStatus.cancelled].
  void cancel();

  /// The current state of the subsystem.
  ScreenSearchState get state;

  /// Stream of state changes for reactive UI updates.
  Stream<ScreenSearchState> get stateStream;

  /// Release resources held by this service.
  Future<void> dispose();
}
