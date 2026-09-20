/// Step 24 — Trigger Platform Service Tests
///
/// Structural tests for TriggerPlatformService (MethodChannel handler).
/// FAIL-CLOSED: engine unavailability → deny trigger safely.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/infrastructure/platform/trigger_platform_service.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/platform/method_channel_constants.dart';

void main() {
  group('TriggerPlatformService', () {
    test('can be instantiated', () {
      final service = TriggerPlatformService();
      expect(service, isNotNull);
    });

    test('pending requests map starts empty', () {
      final service = TriggerPlatformService();
      final request = service.popPendingRequest();
      expect(request, isNull);
    });

    test('sendInAppTrigger adds to pending requests', () {
      final service = TriggerPlatformService();
      service.sendInAppTrigger('inApp-req-001');
      final popped = service.popPendingRequest();
      expect(popped, equals('inApp-req-001'));
    });

    test('popPendingRequest returns and removes the request', () {
      final service = TriggerPlatformService();
      service.sendInAppTrigger('inApp-req-002');
      final first = service.popPendingRequest();
      expect(first, equals('inApp-req-002'));
      final second = service.popPendingRequest();
      expect(second, isNull);
    });

    test('updateTileState is callable without error', () {
      final service = TriggerPlatformService();
      // Structural test — method exists and is callable
      service.updateTileState('active');
    });

    test('checkEngineAvailability is callable', () async {
      final service = TriggerPlatformService();
      // Structural test — method exists
      final available = await service.checkEngineAvailability();
      // Without a real Flutter engine, this should handle gracefully
      // Default may be false (FAIL-CLOSED)
      expect(available, isA<bool>());
    });

    test('notifyProcessingComplete is callable', () {
      final service = TriggerPlatformService();
      service.notifyProcessingComplete('req-done-001');
    });
  });

  group('TriggerMethodChannelConstants', () {
    test('channel name matches spec', () {
      expect(TriggerMethodChannelConstants.channelName,
          equals('com.aura.assistant/trigger_integration'));
    });

    test('method names are non-empty strings', () {
      // Structural: all method name constants exist and are non-empty
      expect(TriggerMethodChannelConstants.methodSendInAppTrigger, isNotEmpty);
      expect(TriggerMethodChannelConstants.methodUpdateTileState, isNotEmpty);
      expect(TriggerMethodChannelConstants.methodCheckEngineAvailability, isNotEmpty);
      expect(TriggerMethodChannelConstants.methodNotifyProcessingComplete, isNotEmpty);
    });

    test('arg keys are non-empty strings', () {
      expect(TriggerMethodChannelConstants.argRequestId, isNotEmpty);
      expect(TriggerMethodChannelConstants.argTileState, isNotEmpty);
    });
  });
}
