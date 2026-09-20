/// vision_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the vision feature module.
/// Required: camera

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class VisionAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'vision';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.camera];

  @override
  bool get requiresAll => true;
}
