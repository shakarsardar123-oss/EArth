/// file_storage_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the file_storage feature module.
/// Required: storage

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class FileStorageAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'file_storage';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.storage];

  @override
  bool get requiresAll => true;
}
