/// State model for the AURA screen-understanding subsystem.
library;

import 'package:meta/meta.dart' show immutable;

import 'screen_understanding_result.dart';

// ── Status enum ──────────────────────────────────────────────────

/// Current status of the screen-understanding subsystem.
enum ScreenUnderstandingStatus {
  /// Vision service is not available or not configured.
  unavailable,

  /// Ready — no analysis in progress.
  idle,

  /// Analysis is currently running.
  analyzing,

  /// Analysis succeeded — [ScreenRepresentation] is available.
  success,

  /// Analysis completed but produced no content.
  noContent,

  /// Analysis was cancelled before completion.
  cancelled,

  /// An error occurred during analysis.
  error,
}

// ── State model ─────────────────────────────────────────────────

/// Sentinel value for copyWith nullable-field clearing.
///
/// When [copyWith] receives [_sentinel] for a nullable field,
/// the field retains its previous value. When it receives `null`,
/// the field is set to `null` (clearing it).
const _sentinel = Object();

/// Immutable state snapshot of the screen-understanding subsystem.
@immutable
class ScreenUnderstandingState {
  const ScreenUnderstandingState({
    this.status = ScreenUnderstandingStatus.idle,
    this.representation,
    this.errorMessage,
    this.lastAnalysisTimestamp,
    this.analysisCount = 0,
    this.isContinuous = false,
    this.throttledCount = 0,
    this.deduplicatedCount = 0,
  });

  /// Current status.
  final ScreenUnderstandingStatus status;

  /// The latest [ScreenRepresentation] if available.
  final ScreenRepresentation? representation;

  /// Error message if [status] is [ScreenUnderstandingStatus.error].
  final String? errorMessage;

  /// Epoch-millis of the last completed analysis.
  final int? lastAnalysisTimestamp;

  /// Total number of completed analyses.
  final int analysisCount;

  /// Whether continuous analysis mode is active.
  final bool isContinuous;

  /// Number of requests rejected due to throttling.
  final int throttledCount;

  /// Number of duplicate frames skipped.
  final int deduplicatedCount;

  /// Whether an analysis is currently in progress.
  bool get isAnalyzing => status == ScreenUnderstandingStatus.analyzing;

  /// Whether a result is available.
  bool get hasResult =>
      status == ScreenUnderstandingStatus.success ||
      status == ScreenUnderstandingStatus.noContent;

  /// Whether the subsystem is in an error state.
  bool get hasError => status == ScreenUnderstandingStatus.error;

  /// Whether the subsystem is idle (not analyzing).
  bool get isIdle =>
      status == ScreenUnderstandingStatus.idle ||
      status == ScreenUnderstandingStatus.unavailable;

  /// Copy with optional field overrides.
  ///
  /// For nullable fields ([representation], [errorMessage],
  /// [lastAnalysisTimestamp]), passing `null` clears the field,
  /// while omitting it retains the previous value. This is
  /// implemented via the [_sentinel] pattern.
  ScreenUnderstandingState copyWith({
    ScreenUnderstandingStatus? status,
    Object? representation = _sentinel,
    Object? errorMessage = _sentinel,
    Object? lastAnalysisTimestamp = _sentinel,
    int? analysisCount,
    bool? isContinuous,
    int? throttledCount,
    int? deduplicatedCount,
  }) {
    return ScreenUnderstandingState(
      status: status ?? this.status,
      representation: identical(representation, _sentinel)
          ? this.representation
          : representation as ScreenRepresentation?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      lastAnalysisTimestamp: identical(lastAnalysisTimestamp, _sentinel)
          ? this.lastAnalysisTimestamp
          : lastAnalysisTimestamp as int?,
      analysisCount: analysisCount ?? this.analysisCount,
      isContinuous: isContinuous ?? this.isContinuous,
      throttledCount: throttledCount ?? this.throttledCount,
      deduplicatedCount: deduplicatedCount ?? this.deduplicatedCount,
    );
  }

  @override
  String toString() =>
      'ScreenUnderstandingState(status: ${status.name}, '
      'texts: ${representation?.textItemCount ?? 0}, '
      'ui: ${representation?.uiElementCount ?? 0}, '
      'regions: ${representation?.regionCount ?? 0}, '
      'analyses: $analysisCount, throttled: $throttledCount, '
      'deduped: $deduplicatedCount)';
}
