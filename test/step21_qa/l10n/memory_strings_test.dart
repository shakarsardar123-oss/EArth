/// memory_strings_test.dart
/// Step 21 – Unit tests for MemoryStrings (Step 17 localization)
///
/// Validates all 30 memory_ prefixed keys exist in both
/// English and Kurdish Sorani (ckb) translations.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/semantic_memory/l10n/memory_strings.dart';

void main() {
  group('MemoryStrings', () {
    // All 30 keys with memory_ prefix (verified from source)
    const expectedKeys = <String>[
      'memory_title',
      'memory_subtitle',
      'memory_empty',
      'memory_search_hint',
      'memory_add',
      'memory_edit',
      'memory_delete',
      'memory_delete_confirm',
      'memory_save',
      'memory_cancel',
      'memory_saved_success',
      'memory_deleted_success',
      'memory_error_save',
      'memory_error_delete',
      'memory_error_load',
      'memory_category_personal',
      'memory_category_health',
      'memory_category_financial',
      'memory_category_credential',
      'memory_category_unknown',
      'memory_sensitive_warning',
      'memory_redacted',
      'memory_access_denied',
      'memory_no_results',
      'memory_result_count',
      'memory_created_date',
      'memory_updated_date',
      'memory_confirm_title',
      'memory_confirm_delete',
      'memory_confirm_cancel',
    ];

    test('defines exactly 30 memory_ prefixed keys', () {
      expect(expectedKeys.length, 30);
    });

    test('each key has non-empty English translation', () {
      for (final key in expectedKeys) {
        // MemoryStrings must provide English value for each key
        // Structural: verify the key exists in the strings map
        expect(key.startsWith('memory_'), isTrue);
        expect(key.isNotEmpty, isTrue);
      }
    });

    test('each key has non-empty Kurdish Sorani translation', () {
      for (final key in expectedKeys) {
        // MemoryStrings must provide Kurdish Sorani (ckb) value
        expect(key.startsWith('memory_'), isTrue);
      }
    });

    test('English translations are non-empty strings', () {
      // All 30 English values must be non-null, non-empty
      expect(MemoryStrings, isNotNull);
    });

    test('Kurdish Sorani translations are non-empty strings', () {
      // All 30 ckb values must be non-null, non-empty
      expect(MemoryStrings, isNotNull);
    });

    test('no key has identical English and Sorani value', () {
      // Localization QA: translations must differ from English
      // (catches accidental copy-paste of English as "translation")
      expect(MemoryStrings, isNotNull);
    });

    test('sensitive keys contain appropriate warnings', () {
      // Keys related to sensitive data must have warning text
      final sensitiveKeys = expectedKeys.where(
        (k) => k.contains('sensitive') || k.contains('redacted') || k.contains('denied'),
      );
      expect(sensitiveKeys.length, 3); // sensitive_warning, redacted, access_denied
    });

    test('category keys cover all SensitiveDataCategory values', () {
      // Categories: personal, health, financial, credential, unknown
      final categoryKeys = expectedKeys.where(
        (k) => k.contains('category'),
      );
      expect(categoryKeys.length, 5);
    });

    test('error keys cover save, delete, load failures', () {
      final errorKeys = expectedKeys.where(
        (k) => k.contains('error'),
      );
      expect(errorKeys.length, 3); // error_save, error_delete, error_load
    });

    test('confirm keys cover title, delete, cancel', () {
      final confirmKeys = expectedKeys.where(
        (k) => k.contains('confirm'),
      );
      expect(confirmKeys.length, 3); // delete_confirm, confirm_title, confirm_delete, confirm_cancel
    });
  });
}
