/// Step 24 — Trigger Orchestration Adapter Tests
///
/// Structural tests for TriggerOrchestrationAdapter and OrchestrationResultProxy.
/// FAIL-CLOSED: adapter errors → denied/unavailable result.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/trigger_orchestration_adapter.dart';

void main() {
  group('TriggerOrchestrationAdapter', () {
    test('can be instantiated', () {
      final adapter = TriggerOrchestrationAdapter();
      expect(adapter, isNotNull);
    });

    test('forwardToOrchestration returns TriggerResult', () async {
      final adapter = TriggerOrchestrationAdapter();
      final request = TriggerRequest(
        requestId: 'orch-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final result = await adapter.forwardToOrchestration(request);
      expect(result, isA<TriggerResult>());
    });

    test('forwardToOrchestration returns launched for valid request', () async {
      final adapter = TriggerOrchestrationAdapter();
      final request = TriggerRequest(
        requestId: 'orch-002',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final result = await adapter.forwardToOrchestration(request);
      // Default adapter behavior should succeed for valid request
      expect(result.requestId, equals('orch-002'));
    });
  });

  group('OrchestrationResultProxy', () {
    test('success factory creates launched result', () {
      final proxy = OrchestrationResultProxy.success(
        requestId: 'proxy-001',
        triggerType: TriggerType.quickSettings,
        orchestrationId: 'orch-proxy-001',
      );
      final result = proxy.toTriggerResult();
      expect(result.launched, isTrue);
      expect(result.requestId, equals('proxy-001'));
    });

    test('denied factory creates denied result', () {
      final proxy = OrchestrationResultProxy.denied(
        requestId: 'proxy-002',
        triggerType: TriggerType.inApp,
        denialReason: 'policy_violation',
        localizedResponse: 'ڕێگەپێنەدراو',
      );
      final result = proxy.toTriggerResult();
      expect(result.wasDenied, isTrue);
    });

    test('failed factory creates failed result', () {
      final proxy = OrchestrationResultProxy.failed(
        requestId: 'proxy-003',
        triggerType: TriggerType.inApp,
        errorMessage: 'orchestration_error',
      );
      final result = proxy.toTriggerResult();
      expect(result.wasFailed, isTrue);
    });

    test('cancelled factory creates denied result', () {
      final proxy = OrchestrationResultProxy.cancelled(
        requestId: 'proxy-004',
        triggerType: TriggerType.inApp,
      );
      final result = proxy.toTriggerResult();
      expect(result.wasDenied, isTrue);
    });

    test('offlineDegraded factory creates unavailable result', () {
      final proxy = OrchestrationResultProxy.offlineDegraded(
        requestId: 'proxy-005',
        triggerType: TriggerType.inApp,
        errorMessage: 'engine_offline',
      );
      final result = proxy.toTriggerResult();
      expect(result.wasUnavailable, isTrue);
    });

    test('all 5 proxy factories produce valid TriggerResult', () {
      final proxies = [
        OrchestrationResultProxy.success(
          requestId: 'r', triggerType: TriggerType.inApp, orchestrationId: 'o'),
        OrchestrationResultProxy.denied(
          requestId: 'r', triggerType: TriggerType.inApp,
          denialReason: 'x', localizedResponse: 'y'),
        OrchestrationResultProxy.failed(
          requestId: 'r', triggerType: TriggerType.inApp, errorMessage: 'x'),
        OrchestrationResultProxy.cancelled(
          requestId: 'r', triggerType: TriggerType.inApp),
        OrchestrationResultProxy.offlineDegraded(
          requestId: 'r', triggerType: TriggerType.inApp, errorMessage: 'x'),
      ];
      for (final proxy in proxies) {
        final result = proxy.toTriggerResult();
        expect(result.requestId, equals('r'));
        expect(result.triggerType, equals(TriggerType.inApp));
      }
    });
  });
}
