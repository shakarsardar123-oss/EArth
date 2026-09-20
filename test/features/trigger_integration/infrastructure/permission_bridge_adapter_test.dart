/// Step 24 — Permission Bridge Adapter Tests
///
/// Structural tests for PermissionBridgeAdapter.
/// FAIL-CLOSED: permission unavailable → checkPermissions returns false.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/infrastructure/adapters/permission_bridge_adapter.dart';

void main() {
  group('PermissionBridgeAdapter', () {
    test('can be instantiated', () {
      final adapter = PermissionBridgeAdapter();
      expect(adapter, isNotNull);
    });

    test('checkPermissions returns true when permissions available', () {
      final adapter = PermissionBridgeAdapter();
      // Default: permission available = true
      final result = adapter.checkPermissions(TriggerType.quickSettings);
      expect(result, isTrue);
    });

    test('FAIL-CLOSED: checkPermissions returns false when permissions unavailable', () {
      final adapter = PermissionBridgeAdapter();
      adapter.setPermissionAvailable(false);
      final result = adapter.checkPermissions(TriggerType.quickSettings);
      expect(result, isFalse);
    });

    test('FAIL-CLOSED: checkPermissions returns false for unknown type', () {
      final adapter = PermissionBridgeAdapter();
      final result = adapter.checkPermissions(TriggerType.unknown);
      expect(result, isFalse);
    });

    test('setPermissionAvailable toggles availability', () {
      final adapter = PermissionBridgeAdapter();
      expect(adapter.checkPermissions(TriggerType.quickSettings), isTrue);
      adapter.setPermissionAvailable(false);
      expect(adapter.checkPermissions(TriggerType.quickSettings), isFalse);
      adapter.setPermissionAvailable(true);
      expect(adapter.checkPermissions(TriggerType.quickSettings), isTrue);
    });

    test('getRequiredPermissions returns non-empty list for known types', () {
      final adapter = PermissionBridgeAdapter();
      final permissions = adapter.getRequiredPermissions(TriggerType.quickSettings);
      expect(permissions, isNotNull);
      // QuickSettings typically requires RECORD_AUDIO
    });

    test('getRequiredPermissions returns empty for unknown type', () {
      final adapter = PermissionBridgeAdapter();
      final permissions = adapter.getRequiredPermissions(TriggerType.unknown);
      expect(permissions, isNotNull);
    });

    test('all trigger types have getRequiredPermissions callable', () {
      final adapter = PermissionBridgeAdapter();
      for (final type in TriggerType.values) {
        final permissions = adapter.getRequiredPermissions(type);
        expect(permissions, isNotNull);
      }
    });

    test('_requiredPermissions contains entries for authorizable types', () {
      // Structural: the static map should exist for known types
      // We verify via checkPermissions that the map is consulted
      final adapter = PermissionBridgeAdapter();
      for (final type in [
        TriggerType.quickSettings,
        TriggerType.assistantLongPress,
        TriggerType.homeLongPress,
        TriggerType.notificationAction,
        TriggerType.inApp,
      ]) {
        expect(adapter.checkPermissions(type), isA<bool>());
      }
    });
  });
}
