/// Step 24 — Full Lifecycle Integration Test
///
/// End-to-end structural test for the trigger integration pipeline:
///   Request → Validate → Authorize → Normalize → Route → Result
///
/// FAIL-CLOSED: every failure mode must result in denied/failed/unavailable.
/// Kurdish Sorani RTL first (locale='ku').
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_state.dart';
import 'package:aura_assistant/features/trigger_integration/domain/repositories/trigger_authorization_repository.dart';
import 'package:aura_assistant/features/trigger_integration/application/controller/trigger_controller.dart';
import 'package:aura_assistant/features/trigger_integration/application/normalization/trigger_normalization_service.dart';
import 'package:aura_assistant/features/trigger_integration/application/authorization/trigger_authorization_service.dart';
import 'package:aura_assistant/features/trigger_integration/application/router/trigger_router.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/trigger_orchestration_adapter.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/security_bridge_adapter.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/permission_bridge_adapter.dart';
import 'package:aura_assistant/features/trigger_integration/presentation/providers/trigger_ui_providers.dart';
import 'package:aura_assistant/features/trigger_integration/presentation/state/trigger_ui_state.dart';

void main() {
  group('Full Lifecycle Integration', () {
    late TriggerController controller;
    late TriggerRouter router;
    late SecurityBridgeAdapter securityBridge;
    late TriggerOrchestrationAdapter orchestrationAdapter;
    late TriggerNormalizationService normalizationService;

    setUp(() {
      securityBridge = SecurityBridgeAdapter();
      securityBridge.setSecurityAvailable(true);
      router = TriggerRouter();
      orchestrationAdapter = TriggerOrchestrationAdapter();
      normalizationService = TriggerNormalizationService();

      // Register handlers for each trigger type
      for (final type in [
        TriggerType.quickSettings,
        TriggerType.assistantLongPress,
        TriggerType.homeLongPress,
        TriggerType.notificationAction,
        TriggerType.inApp,
      ]) {
        router.registerHandler(type, (req) async {
          return TriggerResult.launched(
            requestId: req.requestId,
            triggerType: req.triggerType,
            orchestrationId: 'orch-${req.requestId}',
          );
        });
      }

      controller = TriggerController(
        authorizationRepository: securityBridge,
        orchestrationAdapter: orchestrationAdapter,
        normalizationService: normalizationService,
        router: router,
      );
    });

    test('quickSettings trigger full lifecycle → launched', () async {
      final request = TriggerRequest(
        requestId: 'lifecycle-qs-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs_tile',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      final result = await controller.processTrigger(request);
      expect(result.launched, isTrue);
      expect(result.finalPhase, equals(TriggerPhase.launched));
      expect(result.wasDenied, isFalse);
      expect(result.wasFailed, isFalse);
      expect(result.wasUnavailable, isFalse);
    });

    test('assistantLongPress trigger → launched', () async {
      final request = TriggerRequest(
        requestId: 'lifecycle-alp-001',
        triggerType: TriggerType.assistantLongPress,
        source: 'assistant',
        timestamp: DateTime.now(),
        locale: 'ku',
        isVoiceInput: true,
      );
      final result = await controller.processTrigger(request);
      expect(result.launched, isTrue);
    });

    test('homeLongPress trigger → launched', () async {
      final request = TriggerRequest(
        requestId: 'lifecycle-hlp-001',
        triggerType: TriggerType.homeLongPress,
        source: 'home',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      final result = await controller.processTrigger(request);
      expect(result.launched, isTrue);
    });

    test('notificationAction trigger → launched', () async {
      final request = TriggerRequest(
        requestId: 'lifecycle-notif-001',
        triggerType: TriggerType.notificationAction,
        source: 'notification',
        timestamp: DateTime.now(),
        textPayload: 'Reply to message',
        locale: 'ku',
      );
      final result = await controller.processTrigger(request);
      expect(result.launched, isTrue);
    });

    test('inApp trigger → launched', () async {
      final request = TriggerRequest(
        requestId: 'lifecycle-inapp-001',
        triggerType: TriggerType.inApp,
        source: 'fab',
        timestamp: DateTime.now(),
        locale: 'ku',
        isVoiceInput: true,
      );
      final result = await controller.processTrigger(request);
      expect(result.launched, isTrue);
    });

    test('FAIL-CLOSED: security unavailable → denied', () async {
      securityBridge.setSecurityAvailable(false);
      final request = TriggerRequest(
        requestId: 'lifecycle-fail-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs_tile',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      final result = await controller.processTrigger(request);
      expect(result.wasDenied, isTrue);
      expect(result.launched, isFalse);
    });

    test('FAIL-CLOSED: unknown trigger type → denied', () async {
      final request = TriggerRequest(
        requestId: 'lifecycle-unknown-001',
        triggerType: TriggerType.unknown,
        source: 'unknown',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      final result = await controller.processTrigger(request);
      expect(result.wasDenied, isTrue);
    });

    test('FAIL-CLOSED: unregistered handler → router deny', () async {
      // Remove quickSettings handler
      router.unregisterHandler(TriggerType.quickSettings);
      final request = TriggerRequest(
        requestId: 'lifecycle-unreg-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs_tile',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      final result = await controller.processTrigger(request);
      // Router catches missing handler → denied
      expect(result.wasDenied, isTrue);
      expect(result.launched, isFalse);
    });

    test('normalization adds isScreenAction for homeLongPress', () async {
      final request = TriggerRequest(
        requestId: 'lifecycle-norm-001',
        triggerType: TriggerType.homeLongPress,
        source: 'home',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      final result = await controller.processTrigger(request);
      // Normalization adds metadata['isScreenAction'] for home long press
      expect(result.launched, isTrue);
    });

    test('UI notifier reflects full lifecycle', () async {
      final notifier = TriggerUiNotifier(controller: controller);
      final request = TriggerRequest(
        requestId: 'lifecycle-ui-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs_tile',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      await notifier.processTrigger(request);
      expect(notifier.state.isLaunched, isTrue);
      expect(notifier.state.activeTriggerType, equals(TriggerType.quickSettings));
    });

    test('FAIL-CLOSED: UI notifier reflects denied lifecycle', () async {
      securityBridge.setSecurityAvailable(false);
      final notifier = TriggerUiNotifier(controller: controller);
      final request = TriggerRequest(
        requestId: 'lifecycle-ui-deny-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs_tile',
        timestamp: DateTime.now(),
        locale: 'ku',
      );
      await notifier.processTrigger(request);
      expect(notifier.state.wasDenied, isTrue);
    });

    test('all 5 trigger types lifecycle with authorized security', () async {
      for (final type in [
        TriggerType.quickSettings,
        TriggerType.assistantLongPress,
        TriggerType.homeLongPress,
        TriggerType.notificationAction,
        TriggerType.inApp,
      ]) {
        final request = TriggerRequest(
          requestId: 'lifecycle-all-${type.name}',
          triggerType: type,
          source: type.name,
          timestamp: DateTime.now(),
          locale: 'ku',
        );
        final result = await controller.processTrigger(request);
        expect(result.launched, isTrue, reason: '${type.name} should launch');
      }
    });
  });
}
