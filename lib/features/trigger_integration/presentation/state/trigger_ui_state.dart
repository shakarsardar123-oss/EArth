/// Step 24 — Trigger UI State
///
/// Immutable state model for the trigger integration UI layer.
/// FAIL-CLOSED: default state is idle/denied-oriented.

import '../../domain/value_objects/trigger_type.dart';
import '../../domain/value_objects/trigger_state.dart';
import '../../domain/entities/trigger_result.dart';

class TriggerUiState {
  /// Current phase of the trigger.
  final TriggerPhase currentPhase;

  /// Whether the UI should show a loading indicator.
  final bool isLoading;

  /// Whether the trigger was denied.
  final bool wasDenied;

  /// Whether the trigger failed.
  final bool wasFailed;

  /// Whether the service is unavailable.
  final bool isUnavailable;

  /// Whether the trigger successfully launched.
  final bool isLaunched;

  /// The last trigger result.
  final TriggerResult? lastResult;

  /// Current active trigger type (if any).
  final TriggerType? activeTriggerType;

  /// Error message to display.
  final String? errorMessage;

  /// Localized denial reason.
  final String? localizedDenialReason;

  const TriggerUiState({
    this.currentPhase = TriggerPhase.idle,
    this.isLoading = false,
    this.wasDenied = false,
    this.wasFailed = false,
    this.isUnavailable = false,
    this.isLaunched = false,
    this.lastResult,
    this.activeTriggerType,
    this.errorMessage,
    this.localizedDenialReason,
  });

  /// Initial idle state.
  factory TriggerUiState.initial() => const TriggerUiState();

  /// State when trigger is being processed.
  factory TriggerUiState.validating(TriggerType type) =>
      TriggerUiState(
        currentPhase: TriggerPhase.validating,
        isLoading: true,
        activeTriggerType: type,
      );

  /// State when trigger was denied.
  factory TriggerUiState.denied(TriggerResult result) =>
      TriggerUiState(
        currentPhase: TriggerPhase.denied,
        wasDenied: true,
        lastResult: result,
        activeTriggerType: result.triggerType,
        localizedDenialReason: result.localizedResponse,
      );

  /// State when trigger failed.
  factory TriggerUiState.failed(TriggerResult result) =>
      TriggerUiState(
        currentPhase: TriggerPhase.failed,
        wasFailed: true,
        lastResult: result,
        activeTriggerType: result.triggerType,
        errorMessage: result.errorMessage,
      );

  /// State when service is unavailable.
  factory TriggerUiState.unavailable(TriggerResult result) =>
      TriggerUiState(
        currentPhase: TriggerPhase.unavailable,
        isUnavailable: true,
        lastResult: result,
        activeTriggerType: result.triggerType,
        errorMessage: result.errorMessage,
      );

  /// State when trigger successfully launched.
  factory TriggerUiState.launched(TriggerResult result) =>
      TriggerUiState(
        currentPhase: TriggerPhase.launched,
        isLaunched: true,
        lastResult: result,
        activeTriggerType: result.triggerType,
      );

  @override
  String toString() =>
      'TriggerUiState(phase: $currentPhase, loading: $isLoading, '
      'denied: $wasDenied, type: $activeTriggerType)';
}
