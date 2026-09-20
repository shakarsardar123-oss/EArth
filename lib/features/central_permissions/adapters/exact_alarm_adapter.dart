/// exact_alarm_adapter.dart
/// AURA Assistant – Step 5: Runtime Permission Flows
///
/// Adapter for the exact_alarm feature module.
/// Required: exactAlarm (Android 12+ SCHEDULE_EXACT_ALARM)

import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'feature_permission_adapter.dart';

class ExactAlarmAdapter extends FeaturePermissionAdapter {
  @override
  String get featureName => 'exact_alarm';

  @override
  List<DevicePermission> get requiredPermissions =>
      const [DevicePermission.exactAlarm];

  @override
  bool get requiresAll => true;
}
