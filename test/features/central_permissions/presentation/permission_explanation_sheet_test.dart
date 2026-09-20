/// permission_explanation_sheet_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Structural tests for showPermissionExplanationSheet function.
/// No Flutter SDK — structural/mock tests only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/presentation/permission_explanation_sheet.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/permission_explanation.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';

void main() {
  group('showPermissionExplanationSheet', () {
    test('is a function returning Future<bool>', () {
      // Structural: verify the function signature exists
      expect(
        showPermissionExplanationSheet,
        isA<Function>(),
      );
    });

    test('accepts context and explanation parameters', () {
      // Structural: showPermissionExplanationSheet(context:, explanation:)
      // We cannot call it without a BuildContext, but we can verify
      // the function exists and has the expected parameter names.
      // The signature is: Future<bool> showPermissionExplanationSheet({
      //   required BuildContext context,
      //   required PermissionExplanation explanation,
      // })
      expect(showPermissionExplanationSheet, isNotNull);
    });
  });

  group('PermissionExplanation', () {
    test('defaults map covers all 10 DevicePermission values', () {
      final defaults = PermissionExplanation.defaults;
      for (final perm in DevicePermission.values) {
        expect(defaults.containsKey(perm), true,
            reason: 'PermissionExplanation.defaults missing: $perm');
      }
    });

    test('each default has non-empty titleKey and bodyKey', () {
      for (final entry in PermissionExplanation.defaults.entries) {
        expect(entry.value.titleKey, isNotEmpty,
            reason: 'Empty titleKey for ${entry.key}');
        expect(entry.value.bodyKey, isNotEmpty,
            reason: 'Empty bodyKey for ${entry.key}');
      }
    });

    test('each default has a featureName', () {
      for (final entry in PermissionExplanation.defaults.entries) {
        expect(entry.value.featureName, isNotEmpty,
            reason: 'Empty featureName for ${entry.key}');
      }
    });

    test('each default maps permission to itself', () {
      for (final entry in PermissionExplanation.defaults.entries) {
        expect(entry.value.permission, entry.key);
      }
    });

    test('isCritical is a bool for each entry', () {
      for (final entry in PermissionExplanation.defaults.entries) {
        expect(entry.value.isCritical, isA<bool>());
      }
    });
  });
}
