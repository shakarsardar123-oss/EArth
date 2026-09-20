/// Step 24 — Trigger Controller Tests
///
/// Structural tests for TriggerController.
/// FAIL-CLOSED: validation/authorization/normalization/routing errors → denied.
/// Steps: validate → authorize → normalize → route.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/domain/repositories/trigger_authorization_repository.dart';
import 'package:aura_assistant/features/trigger_integration/application/controller/trigger_controller.dart';
import 'package:aura_assistant/features/trigger_integration/application/normalization/trigger_normalization_service.dart';
import 'package:aura_assistant/features/trigger_integration/application/router/trigger_router.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/trigger_orchestration_adapter.dart';

/// Mock authorization repository — always authorizes.
class _AlwaysAuthorizeRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    return TriggerAuthorizationVerdict.authorized(
      reason: 'test_always_authorize',
      policyId: 'test-policy-001',
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async => true;
}

/// Mock authorization repository — always denies.
class _AlwaysDenyRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    return TriggerAuthorizationVerdict.denied(
      reason: 'test_always_deny',
      policyId: 'test-policy-002',
    );
  }

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async => false;
}

/// Mock authorization repository — throws error.
class _ErrorRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    throw Exception('auth service error');
  }

  @override
  Future<bool> isAvailable() async => throw Exception('unavailable');

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async =>
      throw Exception('type check error');
}

void main() {
  group('TriggerController', () {
    test('processTrigger returns launched when all steps pass', () async {
      final authRepo = _AlwaysAuthorizeRepo();
      final router = TriggerRouter();
      final orchestrationAdapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();

      // Register a handler that returns launched
      router.registerHandler(TriggerType.quickSettings, (req) async {
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-${req.requestId}',
        );
      });

      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: orchestrationAdapter,
        normalizationService: normalizationService,
        router: router,
      );

      final request = TriggerRequest(
        requestId: 'ctrl-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );

      final result = await controller.processTrigger(request);
      expect(result.launched, isTrue);
      expect(result.requestId, equals('ctrl-001'));
    });

    test('FAIL-CLOSED: processTrigger denies when auth denies', () async {
      final authRepo = _AlwaysDenyRepo();
      final router = TriggerRouter();
      final orchestrationAdapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();

      router.registerHandler(TriggerType.inApp, (req) async {
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-${req.requestId}',
        );
      });

      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: orchestrationAdapter,
        normalizationService: normalizationService,
        router: router,
      );

      final request = TriggerRequest(
        requestId: 'ctrl-002',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
      );

      final result = await controller.processTrigger(request);
      expect(result.wasDenied, isTrue);
    });

    test('FAIL-CLOSED: processTrigger denies unknown trigger type', () async {
      final authRepo = _AlwaysAuthorizeRepo();
      final router = TriggerRouter();
      final orchestrationAdapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();

      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: orchestrationAdapter,
        normalizationService: normalizationService,
        router: router,
      );

      final request = TriggerRequest.unknown();
      final result = await controller.processTrigger(request);
      // Unknown type is not authorizable, should be denied
      expect(result.wasDenied, isTrue);
    });

    test('FAIL-CLOSED: processTrigger handles auth errors as denied', () async {
      final authRepo = _ErrorRepo();
      final router = TriggerRouter();
      final orchestrationAdapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();

      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: orchestrationAdapter,
        normalizationService: normalizationService,
        router: router,
      );

      final request = TriggerRequest(
        requestId: 'ctrl-003',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
      );

      final result = await controller.processTrigger(request);
      expect(result.wasDenied, isTrue);
    });

    test('process convenience method delegates to processTrigger', () async {
      final authRepo = _AlwaysAuthorizeRepo();
      final router = TriggerRouter();
      final orchestrationAdapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();

      router.registerHandler(TriggerType.notificationAction, (req) async {
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-convenience',
        );
      });

      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: orchestrationAdapter,
        normalizationService: normalizationService,
        router: router,
      );

      final request = TriggerRequest(
        requestId: 'ctrl-004',
        triggerType: TriggerType.notificationAction,
        source: 'notification',
        timestamp: DateTime.now(),
      );

      final result = await controller.process(request);
      expect(result.launched, isTrue);
    });
  });
}
