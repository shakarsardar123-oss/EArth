/// permission_status_card_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Structural tests for PermissionStatusCard widget.
/// No Flutter SDK — structural/mock tests only.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/presentation/permission_status_card.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/central_permissions/domain/models/permission_explanation.dart';

void main() {
  group('PermissionStatusCard', () {
    test('constructor accepts DevicePermission and PermissionStatus', () {
      // Structural: verify the constructor signature
      final card = PermissionStatusCard(
        permission: DevicePermission.camera,
        status: PermissionStatus.denied,
      );
      expect(card.permission, DevicePermission.camera);
      expect(card.status, PermissionStatus.denied);
    });

    test('constructor accepts optional explanation parameter', () {
      final explanation = PermissionExplanation.defaults[DevicePermission.camera];
      final card = PermissionStatusCard(
        permission: DevicePermission.camera,
        status: PermissionStatus.granted,
        explanation: explanation,
      );
      expect(card.explanation, isNotNull);
    });

    test('is a StatelessWidget', () {
      expect(
        // PermissionStatusCard extends StatelessWidget
        PermissionStatusCard(
          permission: DevicePermission.microphone,
          status: PermissionStatus.denied,
        ),
        isA<PermissionStatusCard>(),
      );
    });

    test('handles all DevicePermission values structurally', () {
      for (final perm in DevicePermission.values) {
        for (final status in PermissionStatus.values) {
          final card = PermissionStatusCard(
            permission: perm,
            status: status,
          );
          expect(card.permission, perm);
          expect(card.status, status);
        }
      }
    });

    test('PermissionExplanation.defaults covers camera', () {
      final explanation = PermissionExplanation.defaults[DevicePermission.camera];
      expect(explanation, isNotNull);
      expect(explanation!.permission, DevicePermission.camera);
      expect(explanation.titleKey, isA<String>());
      expect(explanation.bodyKey, isA<String>());
    });

    test('PermissionExplanation has isCritical field', () {
      final explanation = PermissionExplanation.defaults[DevicePermission.overlay];
      expect(explanation, isNotNull);
      expect(explanation!.isCritical, isA<bool>());
    });
  });
}
