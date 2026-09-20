/// floating_overlay_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the floating_overlay feature module.
/// Required: overlay

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class FloatingOverlayAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'floating_overlay';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.overlay];

  @override
  bool get requiresAll => true;
}
