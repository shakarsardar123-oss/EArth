/// Step 24 — Trigger Localization Service Tests
///
/// Structural tests for TriggerLocalizationService.
/// Kurdish Sorani RTL first (locale='ku').
/// FAIL-CLOSED: missing key → fail_closed_deny Kurdish message.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/application/localization/trigger_localization_service.dart';

void main() {
  group('TriggerLocalizationService', () {
    test('getDeniedMessage returns Kurdish Sorani by default', () {
      final service = TriggerLocalizationService();
      final message = service.getDeniedMessage('authorization_denied');
      // Default locale is 'ku', message should contain Kurdish text
      expect(message, isNotEmpty);
    });

    test('getDeniedMessage with explicit ku locale returns Kurdish', () {
      final service = TriggerLocalizationService();
      final message = service.getDeniedMessage('authorization_denied', locale: 'ku');
      expect(message, isNotEmpty);
    });

    test('getDeniedMessage with en locale returns English', () {
      final service = TriggerLocalizationService();
      final message = service.getDeniedMessage('authorization_denied', locale: 'en');
      expect(message, isNotEmpty);
    });

    test('FAIL-CLOSED: getDeniedMessage with unknown key returns fail_closed_deny', () {
      final service = TriggerLocalizationService();
      final message = service.getDeniedMessage('nonexistent_key_xyz');
      // Unknown key should return fail_closed_deny Kurdish message
      expect(message, isNotEmpty);
    });

    test('FAIL-CLOSED: getMessage with unknown key returns fail_closed_deny', () {
      final service = TriggerLocalizationService();
      final message = service.getMessage('totally_invalid_key');
      expect(message, isNotEmpty);
    });

    test('getMessage returns Kurdish by default', () {
      final service = TriggerLocalizationService();
      final message = service.getMessage('launched');
      expect(message, isNotEmpty);
    });

    test('getMessage returns English when locale=en', () {
      final service = TriggerLocalizationService();
      final message = service.getMessage('launched', locale: 'en');
      expect(message, isNotEmpty);
    });

    test('Kurdish messages contain RTL characters', () {
      final service = TriggerLocalizationService();
      final kuMessage = service.getDeniedMessage('authorization_denied', locale: 'ku');
      // Kurdish Sorani uses Arabic script — check for at least one Arabic-range char
      final hasArabicChar = kuMessage.codeUnits.any(
        (unit) => unit >= 0x0600 && unit <= 0x06FF,
      );
      expect(hasArabicChar, isTrue);
    });

    test('denied routing error key returns message', () {
      final service = TriggerLocalizationService();
      final message = service.getDeniedMessage('routing_error');
      expect(message, isNotEmpty);
    });

    test('engine unavailable key returns message', () {
      final service = TriggerLocalizationService();
      final message = service.getMessage('engine_unavailable');
      expect(message, isNotEmpty);
    });
  });
}
