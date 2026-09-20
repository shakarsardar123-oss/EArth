import 'package:flutter/widgets.dart' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/localization/locale_provider.dart';

/// Verifies the explicit locale → text-direction mapping that the whole RTL
/// fix depends on. MaterialApp.builder wraps the navigator subtree in a
/// Directionality using `locale.textDirection`, so these enum values are the
/// single source of truth for app-wide direction:
///   Kurdish (Sorani) → RTL, English → LTR.
void main() {
  group('AuraLocale.textDirection', () {
    test('Kurdish (ku) is right-to-left', () {
      expect(AuraLocale.ku.textDirection, TextDirection.rtl);
    });

    test('English (en) is left-to-right', () {
      expect(AuraLocale.en.textDirection, TextDirection.ltr);
    });

    test('every supported locale declares an explicit direction', () {
      for (final locale in AuraLocale.values) {
        expect(
          locale.textDirection,
          anyOf(TextDirection.rtl, TextDirection.ltr),
          reason: '${locale.code} must map to a concrete TextDirection',
        );
      }
    });

    test('language codes are as expected', () {
      expect(AuraLocale.ku.code, 'ku');
      expect(AuraLocale.en.code, 'en');
    });
  });
}
