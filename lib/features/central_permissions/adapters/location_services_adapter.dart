/// location_services_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the location_services feature module.
/// Required: location

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class LocationServicesAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'location_services';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.location];

  @override
  bool get requiresAll => true;
}
