/// central_permission_providers_test.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Tests for CentralPermissionProviders (application layer).

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/central_permissions/application/central_permission_providers.dart';

void main() {
  group('CentralPermissionProviders', () {
    test('has all name constants', () {
      expect(CentralPermissionProviders.serviceName, 'central_permission_service');
      expect(CentralPermissionProviders.managerName, 'platform_permission_manager');
      expect(CentralPermissionProviders.controllerName, 'central_permission_controller');
    });

    test('name constants are non-empty strings', () {
      expect(CentralPermissionProviders.serviceName, isNotEmpty);
      expect(CentralPermissionProviders.managerName, isNotEmpty);
      expect(CentralPermissionProviders.controllerName, isNotEmpty);
    });
  });
}
