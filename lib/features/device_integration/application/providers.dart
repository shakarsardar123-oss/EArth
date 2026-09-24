import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/screen_capture/screen_capture_provider.dart';
import '../../../core/screen_search/search_provider.dart';
import '../../../core/screen_understanding/screen_understanding_provider.dart';
import '../infrastructure/adapters/core_screen_adapters.dart';
import '../../central_permissions/application/central_permission_providers.dart';
import '../infrastructure/central_permission_manager_adapter.dart';
import '../infrastructure/android_device_executor.dart';
import '../application/action_validator.dart';
import '../application/action_verifier.dart';
import '../application/target_resolver.dart';
import '../application/device_integration_controller.dart';
import '../domain/models/permission_status.dart';

final deviceIntegrationPermissionManagerProvider =
    Provider<PermissionManager>((ref) {
  return CentralPermissionManagerAdapter(
    service: ref.watch(centralPermissionServiceProvider),
  );
});

final deviceIntegrationActionValidatorProvider =
    Provider<ActionValidator>((ref) {
  return ActionValidator(
    permissionManager:
        ref.watch(deviceIntegrationPermissionManagerProvider),
  );
});

final _coreScreenAdapterBundleProvider =
    Provider<CoreScreenAdapterBundle>((ref) {
  return buildCoreScreenAdapterBundle(
    captureService: ref.watch(screenCaptureServiceProvider),
    understandingService: ref.watch(screenUnderstandingServiceProvider),
    searchService: ref.watch(screenSearchServiceProvider),
  );
});

final deviceIntegrationTargetResolverProvider =
    Provider<TargetResolver>((ref) {
  final bundle = ref.watch(_coreScreenAdapterBundleProvider);
  return TargetResolver(
    screenCapture: bundle.capture,
    screenUnderstanding: bundle.understanding,
    screenSearch: bundle.search,
  );
});

final deviceIntegrationActionVerifierProvider =
    Provider<ActionVerifier>((ref) {
  final bundle = ref.watch(_coreScreenAdapterBundleProvider);
  return ActionVerifier(
    screenCapture: bundle.capture,
    screenUnderstanding: bundle.understanding,
    screenSearch: bundle.search,
  );
});

final deviceIntegrationExecutorProvider =
    Provider<AndroidDeviceExecutor>((ref) {
  return AndroidDeviceExecutor();
});

final deviceIntegrationControllerProvider =
    Provider<DeviceIntegrationController>((ref) {
  return DeviceIntegrationController(
    validator: ref.watch(deviceIntegrationActionValidatorProvider),
    targetResolver: ref.watch(deviceIntegrationTargetResolverProvider),
    executor: ref.watch(deviceIntegrationExecutorProvider),
    verifier: ref.watch(deviceIntegrationActionVerifierProvider),
    permissionManager:
        ref.watch(deviceIntegrationPermissionManagerProvider),
  );
});
