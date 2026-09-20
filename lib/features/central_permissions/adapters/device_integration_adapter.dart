/// device_integration_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the device_integration feature module.
/// Required: accessibility, overlay, screenCapture

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class DeviceIntegrationAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'device_integration';

  @override
  List<DevicePermission> get requiredPermissions => const [
    DevicePermission.accessibility,
    DevicePermission.overlay,
    DevicePermission.screenCapture,
  ];

  @override
  bool get requiresAll => true;
}
