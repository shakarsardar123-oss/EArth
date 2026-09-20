/// voice_screen_adapter.dart
/// AURA Assistant – Step 16: Central Permissions
///
/// Adapter for the voice_screen feature module.
/// Required: microphone

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class VoiceScreenAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'voice_screen';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.microphone];

  @override
  bool get requiresAll => true;
}
