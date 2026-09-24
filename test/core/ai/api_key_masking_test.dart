import 'package:flutter_test/flutter_test.dart';

import 'package:texo/core/ai/api_key_masker.dart';

void main() {
  group('API Key Masking — ApiKeyMasker.mask()', () {
    test('normal-length key shows only last 4 characters', () {
      final masked = ApiKeyMasker.mask('sk-proj-abc123XYZ789');
      expect(masked, endsWith('Z789'));
      expect(masked.length, 12); // 8 + 4
      expect(masked.substring(0, 8), '••••••••');
    });

    test('short key (≤4 chars) shows all bullets', () {
      final masked = ApiKeyMasker.mask('sk-k');
      expect(masked, '••••');
      expect(masked.length, 4);
    });

    test('key of exactly 5 characters shows 8 bullets + last 4', () {
      final masked = ApiKeyMasker.mask('ABCDE');
      expect(masked, '••••••••BCDE');
      expect(masked.length, 12);
    });

    test('key of exactly 4 characters shows 4 bullets', () {
      final masked = ApiKeyMasker.mask('ABCD');
      expect(masked, '••••');
    });

    test('very long key still only shows 8 bullets + last 4', () {
      final longKey = 'sk-proj-' + 'a' * 100;
      final masked = ApiKeyMasker.mask(longKey);
      expect(masked.length, 12);
      expect(masked, endsWith('aaaa'));
    });

    test('masked value does NOT equal the original key', () {
      const key = 'sk-test-abcdef123456';
      final masked = ApiKeyMasker.mask(key);
      expect(masked, isNot(equals(key)));
    });

    test('single character key shows 1 bullet', () {
      final masked = ApiKeyMasker.mask('X');
      expect(masked, '•');
      expect(masked.length, 1);
    });

    test('empty string returns empty', () {
      final masked = ApiKeyMasker.mask('');
      expect(masked, '');
    });

    test('two character key shows 2 bullets', () {
      final masked = ApiKeyMasker.mask('AB');
      expect(masked, '••');
    });

    test('no partial key exposure for keys > 4 chars — only last 4 visible', () {
      const key = 'sk-proj-super-secret-key-12345';
      final masked = ApiKeyMasker.mask(key);
      expect(masked, '••••••••2345');
      expect(masked, isNot(contains('sk-proj')));
      expect(masked, isNot(contains('super-secret')));
    });
  });
}
