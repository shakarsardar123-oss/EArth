/// screen_capture_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the screen_capture feature module.
/// Required: screenCapture

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class ScreenCaptureAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'screen_capture';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.screenCapture];

  @override
  bool get requiresAll => true;
}
