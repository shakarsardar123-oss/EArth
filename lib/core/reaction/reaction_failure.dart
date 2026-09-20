/// Failure model for the Reaction subsystem.
///
/// Follows the project pattern: extend abstract [Failure], add a
/// [ReactionPhase] enum for the lifecycle phase where the failure
/// occurred. Mirrors [FloatingAuraOverlayFailure],
/// [VoiceScreenFailure], [ScreenCaptureFailure], etc.
library;

import '../errors/failures.dart';

/// Failure arising from the Dynamic Reaction System.
class ReactionFailure extends Failure {
  const ReactionFailure({
    required super.message,
    super.code,
    this.phase,
  });

  /// The phase during which the failure occurred.
  final ReactionPhase? phase;
}

/// Phases of the reaction lifecycle where failures can occur.
enum ReactionPhase {
  /// Building the [ReactionContext] from current state.
  contextBuilding,

  /// Looking up reactions in the [ReactionCatalog].
  catalogLookup,

  /// Filtering eligible reactions based on context.
  eligibilityFiltering,

  /// Applying anti-repetition penalties.
  antiRepetition,

  /// Weighted random selection.
  selection,

  /// Cooldown check.
  cooldown,

  /// Engine state management (StateNotifier lifecycle).
  engineState,

  /// Native overlay dispatch (future — MethodChannel call).
  nativeOverlayDispatch,
}
