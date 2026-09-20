import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../core/permissions/permission_service.dart';
import '../../core/errors/result.dart';

/// Provider for the PermissionService instance.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// Provider that tracks microphone permission state.
final micPermissionProvider = StateNotifierProvider<MicPermissionNotifier, AsyncValue<bool>>((ref) {
  return MicPermissionNotifier(ref.watch(permissionServiceProvider));
});

class MicPermissionNotifier extends StateNotifier<AsyncValue<bool>> {
  MicPermissionNotifier(this._permissionService) : super(const AsyncValue.loading());

  final PermissionService _permissionService;

  /// Check current microphone permission status.
  Future<void> checkMicPermission() async {
    try {
      final granted = await _permissionService.isPermissionGranted(ph.Permission.microphone);
      state = AsyncValue.data(granted);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Request microphone permission.
  Future<bool> requestMicPermission() async {
    try {
      state = const AsyncValue.loading();
      final result = await _permissionService.requestPermission(ph.Permission.microphone);
      final granted = result.isSuccess && result.getOrElse(() => false);
      state = AsyncValue.data(granted);
      return granted;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
