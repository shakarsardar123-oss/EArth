/// Step 24 — Trigger UI Providers Tests
///
/// Structural tests for TriggerUiNotifier.
/// FAIL-CLOSED: processing errors → denied state; unknown result → denied state.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/domain/repositories/trigger_authorization_repository.dart';
import 'package:aura_assistant/features/trigger_integration/application/controller/trigger_controller.dart';
import 'package:aura_assistant/features/trigger_integration/application/normalization/trigger_normalization_service.dart';
import 'package:aura_assistant/features/trigger_integration/application/router/trigger_router.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/trigger_orchestration_adapter.dart';
import 'package:aura_assistant/features/trigger_integration/presentation/providers/trigger_ui_providers.dart';
import 'package:aura_assistant/features/trigger_integration/presentation/state/trigger_ui_state.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_state.dart';

/// Mock auth repo — always authorizes
class _MockAuthRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    return TriggerAuthorizationVerdict.authorized(
      reason: 'mock', policyId: 'policy-mock',
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async => true;
}

/// Mock auth repo — always denies
class _MockDenyAuthRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    return TriggerAuthorizationVerdict.denied(
      reason: 'mock_deny', policyId: 'policy-deny',
    );
  }

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async => false;
}

void main() {
  group('TriggerUiNotifier', () {
    test('initial state is idle', () {
      final authRepo = _MockAuthRepo();
      final router = TriggerRouter();
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );
      final notifier = TriggerUiNotifier(controller: controller);
      expect(notifier.state.currentPhase, equals(TriggerPhase.idle));
    });

    test('reset returns state to idle', () async {
      final authRepo = _MockAuthRepo();
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, (req) async {
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-${req.requestId}',
        );
      });
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );
      final notifier = TriggerUiNotifier(controller: controller);

      final request = TriggerRequest(
        requestId: 'notifier-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      await notifier.processTrigger(request);
      // After processing, state is not idle
      expect(notifier.state.currentPhase, isNot(equals(TriggerPhase.idle)));
      // Reset
      notifier.reset();
      expect(notifier.state.currentPhase, equals(TriggerPhase.idle));
    });

    test('processQuickSettings creates correct request type', () async {
      final authRepo = _MockAuthRepo();
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, (req) async {
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-qs',
        );
      });
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );
      final notifier = TriggerUiNotifier(controller: controller);

      await notifier.processQuickSettings(requestId: 'qs-001');
      // Should transition to launched state
      expect(notifier.state.isLaunched, isTrue);
      expect(notifier.state.activeTriggerType, equals(TriggerType.quickSettings));
    });

    test('FAIL-CLOSED: denied auth results in denied UI state', () async {
      final authRepo = _MockDenyAuthRepo();
      final router = TriggerRouter();
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );
      final notifier = TriggerUiNotifier(controller: controller);

      final request = TriggerRequest(
        requestId: 'notifier-002',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      await notifier.processTrigger(request);
      expect(notifier.state.wasDenied, isTrue);
    });

    test('processNotificationAction creates notification-type request', () async {
      final authRepo = _MockAuthRepo();
      final router = TriggerRouter();
      router.registerHandler(TriggerType.notificationAction, (req) async {
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-notif',
        );
      });
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );
      final notifier = TriggerUiNotifier(controller: controller);

      await notifier.processNotificationAction(
        requestId: 'notif-001', actionLabel: 'reply',
      );
      expect(notifier.state.isLaunched, isTrue);
      expect(notifier.state.activeTriggerType, equals(TriggerType.notificationAction));
    });

    test('processQuickSettings defaults to locale=ku and isVoiceInput=true', () async {
      // Structural: verify the convenience method uses correct defaults
      // We test the request that flows through has ku locale
      final authRepo = _MockAuthRepo();
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, (req) async {
        // Verify defaults passed through
        expect(req.locale, equals('ku'));
        expect(req.isVoiceInput, isTrue);
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-defaults',
        );
      });
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: authRepo,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );
      final notifier = TriggerUiNotifier(controller: controller);

      await notifier.processQuickSettings(requestId: 'qs-defaults');
      expect(notifier.state.isLaunched, isTrue);
    });
  });
}
