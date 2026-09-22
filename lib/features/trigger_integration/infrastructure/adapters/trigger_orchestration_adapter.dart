/// Step 24 — Trigger Orchestration Adapter
///
/// Bridges the trigger layer to the real Step 23 orchestration pipeline
/// via [OrchestrationUseCase].
///
/// FAIL-CLOSED: orchestration error → denied result.
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.

import '../../domain/entities/trigger_request.dart';
import '../../domain/entities/trigger_result.dart';
import '../../../orchestration/application/usecases/orchestration_use_case.dart';
import '../../../orchestration/domain/value_objects/orchestration_result.dart';

class TriggerOrchestrationAdapter {
  final OrchestrationUseCase _orchestrationUseCase;

  TriggerOrchestrationAdapter({
    required OrchestrationUseCase orchestrationUseCase,
  }) : _orchestrationUseCase = orchestrationUseCase;

  /// Forward a trigger request to the real Step 23 orchestration pipeline.
  ///
  /// FAIL-CLOSED: if orchestration fails or returns a non-success result,
  /// the trigger result reflects the orchestration outcome (denied/failed).
  Future<TriggerResult> forwardToOrchestration(
    TriggerRequest request,
  ) async {
    try {
      final userRequest = request.textPayload ?? '';
      final locale = request.locale;
      final isVoiceRequest = request.isVoiceInput;
      final isScreenAction =
          request.metadata['isScreenAction'] as bool? ?? false;

      final result = await _orchestrationUseCase.execute(
        userRequest: userRequest,
        locale: locale,
        isVoiceRequest: isVoiceRequest,
        isScreenAction: isScreenAction,
      );

      return _mapOrchestrationResult(result, request);
    } catch (e) {
      // FAIL-CLOSED: orchestration error → denied
      return TriggerResult.failed(
        requestId: request.requestId,
        triggerType: request.triggerType,
        errorCode: 'orchestration_adapter_error',
        errorMessage: e.toString(),
        localizedResponse: 'هەڵە لە بەڕێوەبردنی ئاورا',
      );
    }
  }

  /// Map the real [OrchestrationResult] to a [TriggerResult].
  /// FAIL-CLOSED: unknown orchestration outcome → denied.
  TriggerResult _mapOrchestrationResult(
    OrchestrationResult orchestrationResult,
    TriggerRequest request,
  ) {
    if (orchestrationResult.succeeded) {
      return TriggerResult.launched(
        requestId: request.requestId,
        triggerType: request.triggerType,
        localizedResponse:
            orchestrationResult.localizedResponse ?? 'دەستپێکرا — ئاورا ئامادەیە',
      );
    }

    if (orchestrationResult.wasCancelled) {
      return TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: 'orchestration_cancelled',
        localizedResponse:
            orchestrationResult.localizedResponse ?? 'داواکاریەکە هەڵوەشایەوە',
      );
    }

    if (orchestrationResult.wasDenied) {
      return TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: orchestrationResult.errorCode ?? 'orchestration_denied',
        localizedResponse:
            orchestrationResult.localizedResponse ?? 'ڕێگەپێنەدراو — ئاورا ڕەتیکردەوە',
      );
    }

    if (orchestrationResult.errorCode == 'OFFLINE_DEGRADED') {
      // Offline degraded is still treated as launched — orchestration
      // decided to proceed in degraded mode.
      return TriggerResult.launched(
        requestId: request.requestId,
        triggerType: request.triggerType,
        localizedResponse:
            orchestrationResult.localizedResponse ?? 'دەستپێکرا — دۆخی ناهێڵکێشکەر',
      );
    }

    // Any other non-success phase (e.g. failed) → failed result.
    return TriggerResult.failed(
      requestId: request.requestId,
      triggerType: request.triggerType,
      errorCode: orchestrationResult.errorCode ?? 'orchestration_failed',
      errorMessage: orchestrationResult.errorMessage ?? 'Unknown failure',
      localizedResponse:
          orchestrationResult.localizedResponse ?? 'سەرنەکەوت — هەڵە لە ئاورا',
    );
  }
}
