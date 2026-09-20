/// Step 23 — Orchestration Use Case
///
/// Application-layer use case that drives the orchestration pipeline.
/// Delegates all coordination to AgentOrchestrator.
///
/// FAIL-CLOSED: any error or unknown state → denied.
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.

import '../../domain/orchestration_domain.dart';
import '../orchestrator/agent_orchestrator.dart';

class OrchestrationUseCase {
  final AgentOrchestrator _orchestrator;

  OrchestrationUseCase({required AgentOrchestrator orchestrator})
      : _orchestrator = orchestrator;

  /// Process a user request through the full orchestration pipeline.
  ///
  /// [userRequest] — raw text from user or STT transcript.
  /// [locale] — 'ku' (Kurdish Sorani) by default.
  /// [isVoiceRequest] — true if input came via voice.
  /// [isScreenAction] — true if request involves screen control.
  ///
  /// Returns [OrchestrationResult] — never throws unhandled exceptions.
  Future<OrchestrationResult> execute({
    required String userRequest,
    String locale = 'ku',
    bool isVoiceRequest = false,
    bool isScreenAction = false,
  }) async {
    final requestId = _generateRequestId();
    final context = UnifiedRequestContext.initial(
      requestId: requestId,
      userRequest: userRequest,
      locale: locale,
      isVoiceRequest: isVoiceRequest,
      isScreenAction: isScreenAction,
    );

    try {
      return await _orchestrator.process(context);
    } catch (e) {
      return OrchestrationResult.denied(
        requestId: requestId,
        errorCode: 'USE_CASE_ERROR',
        errorMessage: e.toString(),
        localizedResponse: 'هەڵەیەک ڕوویدا', // Kurdish: An error occurred
      );
    }
  }

  /// Cancel an active orchestration request.
  Future<OrchestrationResult> cancel(UnifiedRequestContext context) async {
    try {
      return await _orchestrator.cancel(context);
    } catch (e) {
      return OrchestrationResult.cancelled(
        requestId: context.requestId,
        localizedResponse: 'داواکاریەکە هەڵوەشایەوە', // Kurdish: Request cancelled
      );
    }
  }

  /// Generate a unique request ID.
  String _generateRequestId() {
    final now = DateTime.now();
    return 'req_${now.millisecondsSinceEpoch}';
  }
}
