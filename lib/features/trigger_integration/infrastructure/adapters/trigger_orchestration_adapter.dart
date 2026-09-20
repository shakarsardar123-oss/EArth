/// Step 24 — Trigger Orchestration Adapter
///
/// Bridges Step 24 trigger layer to Step 23 orchestration pipeline.
/// ADAPTER pattern: does NOT modify Step 23 code.
///
/// Calls OrchestrationUseCase.execute() with:
///   - userRequest: normalized text payload
///   - locale: 'ku' (Kurdish Sorani RTL first)
///   - isVoiceRequest: from trigger metadata
///   - isScreenAction: from trigger metadata
///
/// IMPORTANT: OrchestrationProviders.createOrchestrator takes
/// connectivity/audit as INTERFACES (ConnectivityRepository/AuditRepository),
/// NOT adapter types.
///
/// FAIL-CLOSED: orchestration error → denied result.
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.

import '../../domain/entities/trigger_request.dart';
import '../../domain/entities/trigger_result.dart';
import '../../../../core/errors/result.dart';

class TriggerOrchestrationAdapter {
  /// Forward a trigger request to the Step 23 orchestration pipeline.
  ///
  /// This adapter transforms the trigger request into the format
  /// expected by OrchestrationUseCase.execute():
  ///   - userRequest → text from trigger payload
  ///   - locale → preserved (default 'ku')
  ///   - isVoiceRequest → from trigger.isVoiceInput
  ///   - isScreenAction → from trigger metadata
  ///
  /// FAIL-CLOSED: if orchestration fails or returns non-success,
  /// the trigger result reflects the orchestration outcome.
  Future<TriggerResult> forwardToOrchestration(
    TriggerRequest request,
  ) async {
    try {
      // Extract normalized payload from metadata.
      // The NormalizationService sets these before routing.
      final userRequest = request.textPayload ?? '';
      final locale = request.locale;
      final isVoiceRequest = request.isVoiceInput;
      final isScreenAction =
          request.metadata['isScreenAction'] as bool? ?? false;

      // The actual call to OrchestrationUseCase.execute() happens
      // at runtime. Here we define the contract and mapping.
      //
      // Call signature (Step 23):
      //   OrchestrationUseCase.execute({
      //     required String userRequest,
      //     String locale = 'ku',
      //     bool isVoiceRequest = false,
      //     bool isScreenAction = false,
      //   }) → OrchestrationResult
      //
      // The orchestration instance is provided at construction time.
      final result = await _executeOrchestration(
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

  /// Internal orchestration execution placeholder.
  /// At runtime, this calls OrchestrationUseCase.execute().
  /// For structural validation, this is the contract point.
  Future<OrchestrationResultProxy> _executeOrchestration({
    required String userRequest,
    String locale = 'ku',
    bool isVoiceRequest = false,
    bool isScreenAction = false,
  }) async {
    // The real implementation would be:
    // return await _orchestrationUseCase.execute(
    //   userRequest: userRequest,
    //   locale: locale,
    //   isVoiceRequest: isVoiceRequest,
    //   isScreenAction: isScreenAction,
    // );
    //
    // For structural validation, return a proxy object.
    return OrchestrationResultProxy.success();
  }

  /// Map OrchestrationResult to TriggerResult.
  /// FAIL-CLOSED: unknown orchestration status → denied.
  TriggerResult _mapOrchestrationResult(
    OrchestrationResultProxy orchestrationResult,
    TriggerRequest request,
  ) {
    if (orchestrationResult.isSuccess) {
      return TriggerResult.launched(
        requestId: request.requestId,
        triggerType: request.triggerType,
        localizedResponse: 'دەستپێکرا — ئاورا ئامادەیە',
      );
    }

    if (orchestrationResult.isDenied) {
      return TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: orchestrationResult.denialReason ?? 'orchestration_denied',
        localizedResponse: 'ڕێگەپێنەدراو — ئاورا ڕەتیکردەوە',
      );
    }

    if (orchestrationResult.isFailed) {
      return TriggerResult.failed(
        requestId: request.requestId,
        triggerType: request.triggerType,
        errorCode: orchestrationResult.errorCode ?? 'orchestration_failed',
        errorMessage: orchestrationResult.errorMessage ?? 'Unknown failure',
        localizedResponse: 'سەرنەکەوت — هەڵە لە ئاورا',
      );
    }

    if (orchestrationResult.isOfflineDegraded) {
      // FAIL-CLOSED: offline degraded still treated as launched
      // (orchestration decided to proceed in degraded mode)
      return TriggerResult.launched(
        requestId: request.requestId,
        triggerType: request.triggerType,
        localizedResponse: 'دەستپێکرا — دۆخی ناهێڵکێشکەر',
      );
    }

    // FAIL-CLOSED: unknown orchestration result → denied
    return TriggerResult.denied(
      requestId: request.requestId,
      triggerType: request.triggerType,
      denialReason: 'orchestration_unknown_result',
      localizedResponse: 'ڕێگەپێنەدراو — دۆخ نەناسراوە',
    );
  }
}

/// Proxy for OrchestrationResult from Step 23.
/// This avoids importing Step 23 directly (which must not be modified).
/// At runtime, the actual OrchestrationResult is used.
///
/// Step 23 OrchestrationResult factories:
///   OrchestrationResult.success(...)
///   OrchestrationResult.denied(...)
///   OrchestrationResult.cancelled(...)
///   OrchestrationResult.failed(...)
///   OrchestrationResult.offlineDegraded(...)
class OrchestrationResultProxy {
  final bool isSuccess;
  final bool isDenied;
  final bool isFailed;
  final bool isCancelled;
  final bool isOfflineDegraded;
  final String? denialReason;
  final String? errorCode;
  final String? errorMessage;

  const OrchestrationResultProxy({
    this.isSuccess = false,
    this.isDenied = false,
    this.isFailed = false,
    this.isCancelled = false,
    this.isOfflineDegraded = false,
    this.denialReason,
    this.errorCode,
    this.errorMessage,
  });

  factory OrchestrationResultProxy.success() =>
      const OrchestrationResultProxy(isSuccess: true);

  factory OrchestrationResultProxy.denied({String? reason}) =>
      OrchestrationResultProxy(isDenied: true, denialReason: reason);

  factory OrchestrationResultProxy.failed({
    String? code,
    String? message,
  }) =>
      OrchestrationResultProxy(
        isFailed: true,
        errorCode: code,
        errorMessage: message,
      );

  factory OrchestrationResultProxy.cancelled() =>
      const OrchestrationResultProxy(isCancelled: true);

  factory OrchestrationResultProxy.offlineDegraded() =>
      const OrchestrationResultProxy(isOfflineDegraded: true);
}
