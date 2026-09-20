/// real_time_translation_domain_test.dart
/// Step 27 structural validation — Real-Time Translation domain layer.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Real-Time Translation Domain', () {
    test('TranslationLanguage.kurdishSorani code is ckb_IQ', () {
      expect(TranslationLanguage.kurdishSorani.code, 'ckb_IQ');
    });

    test('TranslationResult.shouldDeny for blocked', () {
      // shouldDeny covers blocked + lowConfidence
      final result = TranslationResult.denied;
      expect(result.shouldDeny, isTrue);
    });

    test('TranslationLanguage.unknown is denied', () {
      expect(TranslationLanguage.unknown.isDenied, isTrue);
    });
  });
}
