/// assistant_integration_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the assistant_integration feature module.
/// Required: assistant

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class AssistantIntegrationAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'assistant_integration';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.assistant];

  @override
  bool get requiresAll => true;
}
