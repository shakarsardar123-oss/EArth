/// Step 23 — Orchestration Result
///
/// The final output of the orchestration pipeline for a single request.
/// Immutable. FAIL-CLOSED: unknown/errors produce a denied/empty result.

import 'orchestration_state.dart';
import '../../../../core/errors/result.dart';

class OrchestrationResult {
  final String requestId;
  final OrchestrationPhase finalPhase;
  final String? responseText;
  final String? localizedResponse;
  final String? errorCode;
  final String? errorMessage;
  final bool wasDenied;
  final bool wasCancelled;
  final bool succeeded;
  final String? selectedToolId;
  final int totalRetryAttempts;

  const OrchestrationResult({
    required this.requestId,
    required this.finalPhase,
    this.responseText,
    this.localizedResponse,
    this.errorCode,
    this.errorMessage,
    this.wasDenied = false,
    this.wasCancelled = false,
    this.succeeded = false,
    this.selectedToolId,
    this.totalRetryAttempts = 0,
  });

  /// Successful orchestration completion.
  factory OrchestrationResult.success({
    required String requestId,
    required String responseText,
    required String localizedResponse,
    String? selectedToolId,
  }) =>
      OrchestrationResult(
        requestId: requestId,
        finalPhase: OrchestrationPhase.completed,
        responseText: responseText,
        localizedResponse: localizedResponse,
        succeeded: true,
        selectedToolId: selectedToolId,
      );

  /// FAIL-CLOSED: denied result — security, permission, or confirmation blocked.
  factory OrchestrationResult.denied({
    required String requestId,
    required String errorCode,
    required String errorMessage,
    required String localizedResponse,
  }) =>
      OrchestrationResult(
        requestId: requestId,
        finalPhase: OrchestrationPhase.failed,
        errorCode: errorCode,
        errorMessage: errorMessage,
        localizedResponse: localizedResponse,
        wasDenied: true,
      );

  /// Cancelled result.
  factory OrchestrationResult.cancelled({
    required String requestId,
    required String localizedResponse,
  }) =>
      OrchestrationResult(
        requestId: requestId,
        finalPhase: OrchestrationPhase.cancelled,
        localizedResponse: localizedResponse,
        wasCancelled: true,
      );

  /// Failed result after recovery was exhausted.
  factory OrchestrationResult.failed({
    required String requestId,
    required String errorCode,
    required String errorMessage,
    required String localizedResponse,
    int totalRetryAttempts = 0,
  }) =>
      OrchestrationResult(
        requestId: requestId,
        finalPhase: OrchestrationPhase.failed,
        errorCode: errorCode,
        errorMessage: errorMessage,
        localizedResponse: localizedResponse,
        totalRetryAttempts: totalRetryAttempts,
      );

  /// Offline degradation result.
  factory OrchestrationResult.offlineDegraded({
    required String requestId,
    required String localizedResponse,
  }) =>
      OrchestrationResult(
        requestId: requestId,
        finalPhase: OrchestrationPhase.failed,
        localizedResponse: localizedResponse,
        errorCode: 'OFFLINE_DEGRADED',
      );

  @override
  String toString() =>
      'OrchestrationResult(requestId: $requestId, phase: $finalPhase, '
      'succeeded: $succeeded, denied: $wasDenied, cancelled: $wasCancelled)';
}
