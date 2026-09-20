/// notifications_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the notifications feature module.
/// Required: notification

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class NotificationsAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'notifications';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.notification];

  @override
  bool get requiresAll => true;
}
