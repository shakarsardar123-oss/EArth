/// Step 24 — Trigger Controller
///
/// Orchestrates the trigger lifecycle: receive → validate → authorize →
/// normalize → route to AURA pipeline.
/// FAIL-CLOSED: any failure in validation, authorization, or normalization
/// results in DENY. UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.
///
/// This controller is THIN — it does NOT duplicate agent/security/permission/
/// recovery/memory logic. It receives, validates, authorizes, normalizes,
/// and forwards to the Step 23 orchestration pipeline.

import '../../domain/value_objects/trigger_type.dart';
import '../../domain/entities/trigger_request.dart';
import '../../domain/entities/trigger_result.dart';
import '../router/trigger_router.dart';
import '../authorization/trigger_authorization_service.dart';
import '../normalization/trigger_normalization_service.dart';
import '../localization/trigger_localization_service.dart';

class TriggerController {
  final TriggerRouter _router;
  final TriggerAuthorizationService _authorizationService;
  final TriggerNormalizationService _normalizationService;
  final TriggerLocalizationService _localizationService;

  TriggerController({
    required TriggerRouter router,
    required TriggerAuthorizationService authorizationService,
    required TriggerNormalizationService normalizationService,
    required TriggerLocalizationService localizationService,
  })  : _router = router,
        _authorizationService = authorizationService,
        _normalizationService = normalizationService,
        _localizationService = localizationService;

  /// Process a trigger request through the full lifecycle.
  /// 1. Validate trigger type (FAIL-CLOSED: unknown → deny)
  /// 2. Authorize against security policy
  /// 3. Normalize payload for AURA pipeline
  /// 4. Route to appropriate handler (which forwards to orchestration)
  Future<TriggerResult> processTrigger(TriggerRequest request) async {
    // Step 1: Validate trigger type
    if (request.triggerType == TriggerType.unknown ||
        !request.triggerType.isAuthorizable) {
      return TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: 'trigger_type_unknown',
        localizedResponse: _localizationService.getDeniedMessage(
          'trigger_type_unknown',
          locale: request.locale,
        ),
      );
    }

    // Step 2: Authorize
    final verdict = await _authorizationService.authorize(request);
    if (!verdict.authorized) {
      return TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: verdict.reason ?? 'authorization_denied',
        localizedResponse: _localizationService.getDeniedMessage(
          verdict.reason ?? 'authorization_denied',
          locale: request.locale,
        ),
      );
    }

    // Step 3: Normalize payload
    final normalized = _normalizationService.normalize(request);

    // Step 4: Route to handler
    try {
      final result = await _router.route(normalized);
      return result;
    } catch (e) {
      // FAIL-CLOSED: routing error → denied
      return TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: 'routing_error',
        localizedResponse: _localizationService.getDeniedMessage(
          'routing_error',
          locale: request.locale,
        ),
      );
    }
  }

  /// Quick convenience: process a trigger from raw parameters.
  Future<TriggerResult> process({
    required String requestId,
    required TriggerType triggerType,
    required String source,
    String? textPayload,
    bool isVoiceInput = false,
    String locale = 'ku',
  }) async {
    final request = TriggerRequest(
      requestId: requestId,
      triggerType: triggerType,
      source: source,
      timestamp: DateTime.now(),
      textPayload: textPayload,
      isVoiceInput: isVoiceInput,
      locale: locale,
    );
    return processTrigger(request);
  }
}
