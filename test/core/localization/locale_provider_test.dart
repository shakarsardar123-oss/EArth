import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/localization/locale_provider.dart';

void main() {
  group('AuraLocale', () {
    test('has exactly two values: ku and en', () {
      expect(AuraLocale.values.length, 2);
      expect(AuraLocale.values, containsAll([AuraLocale.ku, AuraLocale.en]));
    });

    test('ku has correct properties', () {
      expect(AuraLocale.ku.code, 'ku');
      expect(AuraLocale.ku.countryCode, ''); // Kurdish without country code for broader compatibility
      expect(AuraLocale.ku.textDirection, TextDirection.rtl);
    });

    test('en has correct properties', () {
      expect(AuraLocale.en.code, 'en');
      expect(AuraLocale.en.countryCode, 'US');
      expect(AuraLocale.en.textDirection, TextDirection.ltr);
    });

    test('toLocale creates correct Locale objects', () {
      final kuLocale = AuraLocale.ku.toLocale();
      expect(kuLocale.languageCode, 'ku');
      // ku has empty countryCode, so Locale omits it
      expect(kuLocale.countryCode, isEmpty);

      final enLocale = AuraLocale.en.toLocale();
      expect(enLocale.languageCode, 'en');
      expect(enLocale.countryCode, 'US');
    });

    test('default locale is Kurdish (ku)', () {
      // Verify the first value is ku (RTL default for AURA)
      expect(AuraLocale.values.first, AuraLocale.ku);
    });
  });
}
