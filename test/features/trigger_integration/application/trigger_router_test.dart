/// Step 24 — Trigger Router Tests
///
/// Structural tests for TriggerRouter.
/// FAIL-CLOSED: handler errors → denied result.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/application/router/trigger_router.dart';

// Minimal mock handler for structural testing.
Future<TriggerResult> _launchedHandler(TriggerRequest request) async {
  return TriggerResult.launched(
    requestId: request.requestId,
    triggerType: request.triggerType,
    orchestrationId: 'orch-${request.requestId}',
  );
}

Future<TriggerResult> _throwingHandler(TriggerRequest request) async {
  throw Exception('handler explosion');
}

void main() {
  group('TriggerRouter', () {
    test('registers and checks handlers by type', () {
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, _launchedHandler);
      expect(router.hasHandler(TriggerType.quickSettings), isTrue);
      expect(router.hasHandler(TriggerType.inApp), isFalse);
    });

    test('registeredTypes returns registered types only', () {
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, _launchedHandler);
      router.registerHandler(TriggerType.inApp, _launchedHandler);
      expect(router.registeredTypes,
          containsAll([TriggerType.quickSettings, TriggerType.inApp]));
      expect(router.registeredTypes.length, equals(2));
    });

    test('route returns launched result for valid handler', () async {
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, _launchedHandler);
      final request = TriggerRequest(
        requestId: 'req-route-1',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final result = await router.route(request);
      expect(result.launched, isTrue);
      expect(result.requestId, equals('req-route-1'));
    });

    test('FAIL-CLOSED: route with no handler returns denied', () async {
      final router = TriggerRouter();
      // No handler registered for inApp
      final request = TriggerRequest(
        requestId: 'req-route-2',
        triggerType: TriggerType.inApp,
        source: 'app',
        timestamp: DateTime.now(),
      );
      final result = await router.route(request);
      expect(result.wasDenied, isTrue);
      expect(result.requestId, equals('req-route-2'));
    });

    test('FAIL-CLOSED: route with throwing handler returns denied', () async {
      final router = TriggerRouter();
      router.registerHandler(TriggerType.notificationAction, _throwingHandler);
      final request = TriggerRequest(
        requestId: 'req-route-3',
        triggerType: TriggerType.notificationAction,
        source: 'notification',
        timestamp: DateTime.now(),
      );
      final result = await router.route(request);
      expect(result.wasDenied, isTrue);
      expect(result.requestId, equals('req-route-3'));
    });

    test('unregisterHandler removes handler', () {
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, _launchedHandler);
      expect(router.hasHandler(TriggerType.quickSettings), isTrue);
      router.unregisterHandler(TriggerType.quickSettings);
      expect(router.hasHandler(TriggerType.quickSettings), isFalse);
    });
  });
}
