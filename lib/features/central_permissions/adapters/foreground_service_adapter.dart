/// foreground_service_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the foreground_service feature module.
/// Required: batteryOptimization

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class ForegroundServiceAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'foreground_service';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.batteryOptimization];

  @override
  bool get requiresAll => true;
}
