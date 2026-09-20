/// Step 24 — Trigger Providers
///
/// Dependency wiring for the trigger integration feature.
/// Follows the same pattern as Step 23 OrchestrationProviders:
/// pure factory, all dependencies are INTERFACES.
///
/// IMPORTANT: OrchestrationProviders.createOrchestrator takes
/// connectivity/audit as INTERFACES (ConnectivityRepository/AuditRepository),
/// NOT adapter types. This provider layer bridges Step 24 adapters
/// to those interfaces without modifying Step 23.

import '../../domain/repositories/trigger_authorization_repository.dart';
import '../../domain/entities/trigger_request.dart';
import '../../domain/entities/trigger_result.dart';
import '../../domain/value_objects/trigger_type.dart';
import '../router/trigger_router.dart';
import '../controller/trigger_controller.dart';
import '../authorization/trigger_authorization_service.dart';
import '../normalization/trigger_normalization_service.dart';
import '../localization/trigger_localization_service.dart';
import '../../infrastructure/adapters/trigger_orchestration_adapter.dart';

typedef TriggerTypeHandler = Future<TriggerResult> Function(
  TriggerRequest request,
);

class TriggerProviders {
  /// Create the trigger controller with all dependencies wired.
  /// All dependencies are injected as INTERFACES for testability.
  static TriggerController createController({
    required TriggerAuthorizationRepository authorizationRepository,
    required TriggerOrchestrationAdapter orchestrationAdapter,
    String defaultLocale = 'ku',
  }) {
    final localizationService = TriggerLocalizationService(
      defaultLocale: defaultLocale,
    );

    final normalizationService = TriggerNormalizationService();

    final authorizationService = TriggerAuthorizationService(
      repository: authorizationRepository,
    );

    // Create trigger-specific handlers that bridge to orchestration.
    final handlers = <TriggerType, TriggerTypeHandler>{};
    for (final type in TriggerType.values) {
      if (type.isAuthorizable) {
        handlers[type] = (request) async {
          return orchestrationAdapter.forwardToOrchestration(request);
        };
      }
    }

    // FAIL-CLOSED deny handler.
    TriggerTypeHandler denyHandler = (request) async {
      return TriggerResult.denied(
        requestId: request.requestId,
        triggerType: request.triggerType,
        denialReason: 'fail_closed_deny',
        localizedResponse: localizationService.getDeniedMessage(
          'fail_closed_deny',
          locale: request.locale,
        ),
      );
    };

    final router = TriggerRouter(
      handlers: handlers,
      denyHandler: denyHandler,
    );

    return TriggerController(
      router: router,
      authorizationService: authorizationService,
      normalizationService: normalizationService,
      localizationService: localizationService,
    );
  }
}
