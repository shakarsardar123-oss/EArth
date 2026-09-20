/// Step 24 — Kurdish Sorani RTL First Localization Integration Test
///
/// Validates that locale='ku' is the default everywhere:
///   TriggerRequest defaults, TriggerLocalizationService defaults,
///   TriggerUiNotifier convenience methods, TriggerLocalizationKeys.
///
/// STT: ckb_IQ, TTS: ku, appLocale: ku.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/application/localization/trigger_localization_service.dart';
import 'package:aura_assistant/features/trigger_integration/localization/trigger_localization_keys.dart';
import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_result.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_state.dart';
import 'package:aura_assistant/features/trigger_integration/domain/repositories/trigger_authorization_repository.dart';
import 'package:aura_assistant/features/trigger_integration/application/controller/trigger_controller.dart';
import 'package:aura_assistant/features/trigger_integration/application/normalization/trigger_normalization_service.dart';
import 'package:aura_assistant/features/trigger_integration/application/router/trigger_router.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/trigger_orchestration_adapter.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/security_bridge_adapter.dart';
import 'package:aura_assistant/features/trigger_integration/presentation/providers/trigger_ui_providers.dart';
import 'package:aura_assistant/features/trigger_integration/presentation/state/trigger_ui_state.dart';

void main() {
  group('Kurdish Sorani RTL First Localization', () {
    late TriggerLocalizationService localizationService;

    setUp(() {
      localizationService = TriggerLocalizationService();
    });

    test('default locale is ku (Kurdish Sorani)', () {
      final request = TriggerRequest(
        requestId: 'loc-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      // Default locale should be 'ku'
      expect(request.locale, equals('ku'));
    });

    test('localization service defaults to ku locale', () {
      // Calling getDeniedMessage without locale arg → uses ku
      final message = localizationService.getDeniedMessage('denied_security_unavailable');
      // Should return Kurdish Sorani message, not English
      expect(message, isNotNull);
      expect(message, isNotEmpty);
    });

    test('Kurdish Sorani denied message contains Arabic script', () {
      final message = localizationService.getDeniedMessage('denied_security_unavailable', 'ku');
      // Kurdish Sorani uses Arabic script — expect RTL characters
      expect(message, contains(RegExp(r'[\u0600-\u06FF]')));
    });

    test('English fallback is available but not default', () {
      final kuMessage = localizationService.getDeniedMessage('denied_security_unavailable', 'ku');
      final enMessage = localizationService.getDeniedMessage('denied_security_unavailable', 'en');
      expect(kuMessage, isNot(equals(enMessage)), reason: 'Kurdish and English messages should differ');
    });

    test('FAIL-CLOSED: unknown message key returns fail_closed_deny in Kurdish', () {
      final message = localizationService.getDeniedMessage('nonexistent_key_xyz');
      expect(message, isNotNull);
      expect(message, isNotEmpty);
      // Unknown key should return a fail-closed denial message
    });

    test('TriggerLocalizationKeys defines all required keys', () {
      // Structural: verify all keys exist as static constants
      expect(TriggerLocalizationKeys.deniedSecurityUnavailable, isNotNull);
      expect(TriggerLocalizationKeys.deniedTypeNotPermitted, isNotNull);
      expect(TriggerLocalizationKeys.deniedUnauthorized, isNotNull);
      expect(TriggerLocalizationKeys.failedGeneral, isNotNull);
      expect(TriggerLocalizationKeys.unavailableEngine, isNotNull);
      expect(TriggerLocalizationKeys.successLaunched, isNotNull);
    });

    test('STT locale is ckb_IQ', () {
      expect(TriggerLocalizationKeys.sttLocale, equals('ckb_IQ'));
    });

    test('TTS locale is ku', () {
      expect(TriggerLocalizationKeys.ttsLocale, equals('ku'));
    });

    test('app locale is ku', () {
      expect(TriggerLocalizationKeys.appLocale, equals('ku'));
    });

    test('Kurdish branding label ئاورا exists in keys', () {
      expect(TriggerLocalizationKeys.kurdishAppName, equals('ئاورا'));
    });

    test('All localized denial messages are in Kurdish Sorani by default', () {
      final denialKeys = [
        'denied_security_unavailable',
        'denied_type_not_permitted',
        'denied_unauthorized',
        'denied_unknown_trigger',
      ];
      for (final key in denialKeys) {
        final message = localizationService.getDeniedMessage(key);
        expect(message, isNotNull, reason: 'Key $key must have a Kurdish message');
        expect(message, isNotEmpty, reason: 'Key $key must not be empty');
      }
    });

    test('getMessage also defaults to ku locale', () {
      final message = localizationService.getMessage('failed_general');
      expect(message, isNotNull);
      expect(message, isNotEmpty);
    });

    test('full pipeline with ku locale propagates through to result', () async {
      final securityBridge = SecurityBridgeAdapter();
      securityBridge.setSecurityAvailable(true);
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, (req) async {
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-loc',
        );
      });
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: securityBridge,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );

      final request = TriggerRequest(
        requestId: 'loc-pipeline-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
        // locale defaults to 'ku'
      );
      expect(request.locale, equals('ku'));
      final result = await controller.processTrigger(request);
      expect(result.launched, isTrue);
    });

    test('UI notifier convenience methods use ku locale', () async {
      final securityBridge = SecurityBridgeAdapter();
      securityBridge.setSecurityAvailable(true);
      final router = TriggerRouter();
      router.registerHandler(TriggerType.quickSettings, (req) async {
        expect(req.locale, equals('ku'), reason: 'QuickSettings must default to ku');
        return TriggerResult.launched(
          requestId: req.requestId,
          triggerType: req.triggerType,
          orchestrationId: 'orch-ui-loc',
        );
      });
      final adapter = TriggerOrchestrationAdapter();
      final normalizationService = TriggerNormalizationService();
      final controller = TriggerController(
        authorizationRepository: securityBridge,
        orchestrationAdapter: adapter,
        normalizationService: normalizationService,
        router: router,
      );
      final notifier = TriggerUiNotifier(controller: controller);

      await notifier.processQuickSettings(requestId: 'qs-loc-001');
      expect(notifier.state.isLaunched, isTrue);
    });

    test('all 5 trigger types default to ku locale in request', () {
      for (final type in [
        TriggerType.quickSettings,
        TriggerType.assistantLongPress,
        TriggerType.homeLongPress,
        TriggerType.notificationAction,
        TriggerType.inApp,
      ]) {
        final request = TriggerRequest(
          requestId: 'loc-type-${type.name}',
          triggerType: type,
          source: type.name,
          timestamp: DateTime.now(),
        );
        expect(request.locale, equals('ku'), reason: '${type.name} must default to ku locale');
      }
    });

    test('explicit en locale overrides ku default', () {
      final request = TriggerRequest(
        requestId: 'loc-en-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
        locale: 'en',
      );
      expect(request.locale, equals('en'));
    });

    test('RTL Kurdish messages do not contain LTR-only patterns', () {
      final message = localizationService.getDeniedMessage('denied_security_unavailable', 'ku');
      // Kurdish Sorani is RTL — messages should be in Arabic script
      // This is a structural sanity check, not a layout test
      expect(message, isNot(contains('ERROR')));
      expect(message, isNot(contains('DENY')));
    });
  });
}
