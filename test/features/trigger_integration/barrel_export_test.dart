/// Step 24 — Barrel Export Tests
///
/// Structural tests verifying barrel export files import without error.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/trigger_integration.dart';
import 'package:aura_assistant/features/trigger_integration/domain/trigger_integration_domain.dart';
import 'package:aura_assistant/features/trigger_integration/application/trigger_integration_application.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/trigger_integration_infrastructure.dart';
import 'package:aura_assistant/features/trigger_integration/presentation/trigger_integration_presentation.dart';
import 'package:aura_assistant/features/trigger_integration/localization/trigger_localization_keys.dart';

void main() {
  group('Barrel Exports', () {
    test('top-level barrel re-exports domain', () {
      // If this compiles, the barrel is structurally valid
      // Verify key types are accessible through the barrel
      final type = TriggerType.quickSettings;
      expect(type, isNotNull);
    });

    test('domain barrel exports value objects', () {
      final triggerType = TriggerType.quickSettings;
      final phase = TriggerPhase.idle;
      expect(triggerType, isNotNull);
      expect(phase, isNotNull);
    });

    test('domain barrel exports entities', () {
      final request = TriggerRequest(
        requestId: 'barrel-001',
        triggerType: TriggerType.quickSettings,
        source: 'test',
        timestamp: DateTime.now(),
      );
      expect(request, isNotNull);
    });

    test('application barrel exports controller', () {
      // TriggerController is accessible via barrel
      expect(TriggerController, isNotNull);
    });

    test('application barrel exports router', () {
      final router = TriggerRouter();
      expect(router, isNotNull);
    });

    test('application barrel exports services', () {
      final normalizationService = TriggerNormalizationService();
      final localizationService = TriggerLocalizationService();
      final authService = TriggerAuthorizationService(
        authorizationRepository: _MockAuthRepo(),
      );
      expect(normalizationService, isNotNull);
      expect(localizationService, isNotNull);
      expect(authService, isNotNull);
    });

    test('infrastructure barrel exports adapters', () {
      final orchestrationAdapter = TriggerOrchestrationAdapter();
      final securityBridge = SecurityBridgeAdapter();
      final permissionAdapter = PermissionBridgeAdapter();
      expect(orchestrationAdapter, isNotNull);
      expect(securityBridge, isNotNull);
      expect(permissionAdapter, isNotNull);
    });

    test('presentation barrel exports UI state and providers', () {
      final uiState = TriggerUiState.initial();
      expect(uiState, isNotNull);
      // TriggerUiNotifier requires controller, so we verify the type exists
      expect(TriggerUiNotifier, isNotNull);
    });

    test('localization barrel exports keys', () {
      expect(TriggerLocalizationKeys.appLocale, equals('ku'));
      expect(TriggerLocalizationKeys.sttLocale, equals('ckb_IQ'));
      expect(TriggerLocalizationKeys.ttsLocale, equals('ku'));
      expect(TriggerLocalizationKeys.kurdishAppName, equals('ئاورا'));
    });

    test('top-level barrel re-exports all sub-barrels', () {
      // All types accessible from top-level import
      final type = TriggerType.quickSettings;
      final phase = TriggerPhase.idle;
      final request = TriggerRequest(
        requestId: 'barrel-top-001',
        triggerType: type,
        source: 'test',
        timestamp: DateTime.now(),
      );
      final router = TriggerRouter();
      final adapter = TriggerOrchestrationAdapter();
      final bridge = SecurityBridgeAdapter();
      final permAdapter = PermissionBridgeAdapter();
      final uiState = TriggerUiState.initial();
      final normService = TriggerNormalizationService();
      final locService = TriggerLocalizationService();

      expect(type, isNotNull);
      expect(phase, isNotNull);
      expect(request, isNotNull);
      expect(router, isNotNull);
      expect(adapter, isNotNull);
      expect(bridge, isNotNull);
      expect(permAdapter, isNotNull);
      expect(uiState, isNotNull);
      expect(normService, isNotNull);
      expect(locService, isNotNull);
    });
  });
}

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
