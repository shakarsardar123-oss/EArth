/// State model for the [ReactionEngine].
///
/// Follows the project pattern of immutable state with const constructor
/// and copyWith (e.g. [FloatingAuraState], [VoiceScreenState]).
///
/// The engine is a [StateNotifier] that manages transitions between
/// states as reactions are evaluated and selected.
///
/// Step 5: Added [bannerLifecycle] to track the banner animation phase.
library;

import 'package:meta/meta.dart' show immutable;

import 'reaction_model.dart';
import 'reaction_lifecycle.dart';

/// Status of the reaction engine.
enum ReactionEngineStatus {
  /// Engine initialized, no reaction active.
  idle,

  /// Engine is evaluating a reaction request.
  evaluating,

  /// A reaction was selected and is being displayed.
  /// Stays in this state until the banner UI signals completion.
  reacting,

  /// Engine encountered an error.
  error;

  /// Whether the engine is actively processing.
  bool get isActive =>
      this == ReactionEngineStatus.evaluating ||
      this == ReactionEngineStatus.reacting;
}

/// Immutable state snapshot for the reaction engine.
@immutable
class ReactionState {
  const ReactionState({
    this.status = ReactionEngineStatus.idle,
    this.currentReaction,
    this.lastReactionId,
    this.lastSelectedAt,
    this.totalSelections = 0,
    this.lastError,
    this.bannerLifecycle = ReactionBannerLifecycle.idle,
  });

  /// Current engine status.
  final ReactionEngineStatus status;

  /// The currently active reaction (if any).
  final Reaction? currentReaction;

  /// Id of the most recently selected reaction.
  final String? lastReactionId;

  /// When the last reaction was selected.
  final DateTime? lastSelectedAt;

  /// Cumulative count of successful selections.
  final int totalSelections;

  /// Last error message (if status is error).
  final String? lastError;

  /// Current banner animation lifecycle phase.
  final ReactionBannerLifecycle bannerLifecycle;

  /// Whether a reaction is currently active (status is reacting
  /// AND banner is on-screen or exiting).
  bool get hasActiveReaction =>
      currentReaction != null &&
      status == ReactionEngineStatus.reacting;

  /// Whether the banner is currently visible on screen.
  bool get isBannerOnScreen => bannerLifecycle.isOnScreen;

  /// Whether the banner has finished its full animation.
  bool get isBannerCompleted => bannerLifecycle.isFinished;

  static const ReactionState initial = ReactionState();

  ReactionState copyWith({
    ReactionEngineStatus? status,
    Reaction? currentReaction,
    bool clearCurrentReaction = false,
    String? lastReactionId,
    bool clearLastReactionId = false,
    DateTime? lastSelectedAt,
    bool clearLastSelectedAt = false,
    int? totalSelections,
    String? lastError,
    bool clearLastError = false,
    ReactionBannerLifecycle? bannerLifecycle,
  }) {
    return ReactionState(
      status: status ?? this.status,
      currentReaction: clearCurrentReaction ? null : (currentReaction ?? this.currentReaction),
      lastReactionId: clearLastReactionId ? null : (lastReactionId ?? this.lastReactionId),
      lastSelectedAt: clearLastSelectedAt ? null : (lastSelectedAt ?? this.lastSelectedAt),
      totalSelections: totalSelections ?? this.totalSelections,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      bannerLifecycle: bannerLifecycle ?? this.bannerLifecycle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReactionState &&
        other.status == status &&
        other.currentReaction == currentReaction &&
        other.lastReactionId == lastReactionId &&
        other.totalSelections == totalSelections &&
        other.lastError == lastError &&
        other.bannerLifecycle == bannerLifecycle;
  }

  @override
  int get hashCode => Object.hash(
        status,
        currentReaction,
        lastReactionId,
        totalSelections,
        lastError,
        bannerLifecycle,
      );

  @override
  String toString() =>
      'ReactionState(status: $status, current: ${currentReaction?.id}, '
      'lifecycle: $bannerLifecycle, total: $totalSelections)';
}
