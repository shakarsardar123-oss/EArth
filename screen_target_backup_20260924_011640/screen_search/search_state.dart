/// State model for the AURA screen-search / target-detection subsystem.
library;

import 'package:meta/meta.dart' show immutable;

import 'search_result.dart';

// ── Status enum ──────────────────────────────────────────────────

/// Current status of the screen-search subsystem.
enum ScreenSearchStatus {
  /// Ready — no search in progress.
  idle,

  /// Search is currently running.
  searching,

  /// Search succeeded — results are available.
  success,

  /// Search completed but found no matches.
  noResults,

  /// The search was cancelled before completion.
  cancelled,

  /// An error occurred during search.
  error,
}

// ── State model ─────────────────────────────────────────────────

/// Sentinel value for copyWith nullable-field clearing.
///
/// When [copyWith] receives [_sentinel] for a nullable field,
/// the field retains its previous value. When it receives `null`,
/// the field is set to `null` (clearing it).
const _sentinel = Object();

/// Immutable state snapshot of the screen-search subsystem.
@immutable
class ScreenSearchState {
  const ScreenSearchState({
    this.status = ScreenSearchStatus.idle,
    this.results,
    this.errorMessage,
    this.searchCount = 0,
    this.lastSearchTimestamp,
  });

  /// Current status.
  final ScreenSearchStatus status;

  /// The latest [SearchResults] if available.
  final SearchResults? results;

  /// Error message if [status] is [ScreenSearchStatus.error].
  final String? errorMessage;

  /// Total number of completed searches.
  final int searchCount;

  /// Epoch-millis of the last completed search.
  final int? lastSearchTimestamp;

  /// Whether a search is currently in progress.
  bool get isSearching => status == ScreenSearchStatus.searching;

  /// Whether results are available.
  bool get hasResults =>
      status == ScreenSearchStatus.success ||
      status == ScreenSearchStatus.noResults;

  /// Whether the subsystem is in an error state.
  bool get hasError => status == ScreenSearchStatus.error;

  /// Whether the subsystem is idle.
  bool get isIdle => status == ScreenSearchStatus.idle;

  /// Copy with optional field overrides.
  ///
  /// For nullable fields ([results], [errorMessage],
  /// [lastSearchTimestamp]), passing `null` clears the field,
  /// while omitting it retains the previous value. This is
  /// implemented via the [_sentinel] pattern.
  ScreenSearchState copyWith({
    ScreenSearchStatus? status,
    Object? results = _sentinel,
    Object? errorMessage = _sentinel,
    int? searchCount,
    Object? lastSearchTimestamp = _sentinel,
  }) {
    return ScreenSearchState(
      status: status ?? this.status,
      results: identical(results, _sentinel)
          ? this.results
          : results as SearchResults?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      searchCount: searchCount ?? this.searchCount,
      lastSearchTimestamp: identical(lastSearchTimestamp, _sentinel)
          ? this.lastSearchTimestamp
          : lastSearchTimestamp as int?,
    );
  }

  @override
  String toString() =>
      'ScreenSearchState(status: ${status.name}, '
      'results: ${results?.count ?? 0}, searches: $searchCount)';
}
