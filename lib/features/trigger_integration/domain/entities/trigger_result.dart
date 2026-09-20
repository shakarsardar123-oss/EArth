/// Step 24 — Trigger Result
///
/// Immutable domain entity representing the outcome of processing a trigger.
/// FAIL-CLOSED: unknown/errors produce a denied/failed result.
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.

import '../value_objects/trigger_type.dart';
import '../value_objects/trigger_state.dart';

class TriggerResult {
  /// The trigger request ID this result corresponds to.
  final String requestId;

  /// Final phase of the trigger after processing.
  final TriggerPhase finalPhase;

  /// Whether the trigger was successfully launched into the AURA pipeline.
  final bool launched;

  /// Whether the trigger was denied by security/authorization.
  final bool wasDenied;

  /// Whether the trigger was failed (unrecoverable error).
  final bool wasFailed;

  /// Whether the trigger service was unavailable.
  final bool wasUnavailable;

  /// Error code if applicable.
  final String? errorCode;

  /// Error message if applicable.
  final String? errorMessage;

  /// Denial reason if denied.
  final String? denialReason;

  /// Localized response for the user — Kurdish Sorani RTL first.
  final String? localizedResponse;

  /// The original trigger type.
  final TriggerType triggerType;

  const TriggerResult({
    required this.requestId,
    required this.finalPhase,
    this.launched = false,
    this.wasDenied = false,
    this.wasFailed = false,
    this.wasUnavailable = false,
    this.errorCode,
    this.errorMessage,
    this.denialReason,
    this.localizedResponse,
    required this.triggerType,
  });

  /// Successful launch — trigger forwarded to AURA pipeline.
  factory TriggerResult.launched({
    required String requestId,
    required TriggerType triggerType,
    String? localizedResponse,
  }) =>
      TriggerResult(
        requestId: requestId,
        finalPhase: TriggerPhase.launched,
        launched: true,
        triggerType: triggerType,
        localizedResponse: localizedResponse,
      );

  /// FAIL-CLOSED: denied result.
  factory TriggerResult.denied({
    required String requestId,
    required TriggerType triggerType,
    required String denialReason,
    required String localizedResponse,
  }) =>
      TriggerResult(
        requestId: requestId,
        finalPhase: TriggerPhase.denied,
        wasDenied: true,
        denialReason: denialReason,
        localizedResponse: localizedResponse,
        triggerType: triggerType,
      );

  /// FAIL-CLOSED: failed result (unrecoverable error).
  factory TriggerResult.failed({
    required String requestId,
    required TriggerType triggerType,
    required String errorCode,
    required String errorMessage,
    required String localizedResponse,
  }) =>
      TriggerResult(
        requestId: requestId,
        finalPhase: TriggerPhase.failed,
        wasFailed: true,
        errorCode: errorCode,
        errorMessage: errorMessage,
        localizedResponse: localizedResponse,
        triggerType: triggerType,
      );

  /// FAIL-CLOSED: unavailable result (Flutter engine not running, etc.).
  factory TriggerResult.unavailable({
    required String requestId,
    required TriggerType triggerType,
    required String errorMessage,
    required String localizedResponse,
  }) =>
      TriggerResult(
        requestId: requestId,
        finalPhase: TriggerPhase.unavailable,
        wasUnavailable: true,
        errorMessage: errorMessage,
        localizedResponse: localizedResponse,
        triggerType: triggerType,
      );

  @override
  String toString() =>
      'TriggerResult(requestId: $requestId, phase: $finalPhase, '
      'launched: $launched, denied: $wasDenied, type: $triggerType)';
}
