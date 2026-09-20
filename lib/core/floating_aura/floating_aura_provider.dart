/// Riverpod providers for the AURA floating overlay subsystem.
///
/// Provides:
/// - [floatingAuraServiceProvider] – Platform-aware service instance.
/// - [floatingAuraSupportedProvider] – Whether overlay is supported.
/// - [FloatingAuraStateNotifier] – Manages overlay state transitions,
///   coordinates with the security policy (Step 7), and persists
///   position via [LocalStorageDataSource].
/// - [floatingAuraStateProvider] – Exposes [FloatingAuraState] to
///   the widget tree.
///
/// Pattern follows screen capture providers.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../errors/result.dart';
import '../errors/failures.dart';
import '../constants/app_constants.dart';
import '../security/security_policy.dart';
import '../tools/tool_permission.dart';
import '../permissions/permission_service.dart';
import '../../data/datasources/local_storage_data_source.dart';
import '../../presentation/providers/app_providers.dart';
import '../permissions/permission_provider.dart';
import '../security/security_providers.dart';
import 'floating_aura_service.dart';
import 'floating_aura_state.dart';
import 'floating_aura_overlay_position.dart';
import 'floating_aura_method_channel.dart';
import 'floating_aura_stub_channel.dart';

/// Platform-aware [FloatingAuraService] provider.
///
/// Returns [FloatingAuraMethodChannel] on Android,
/// [FloatingAuraStubChannel] everywhere else.
final floatingAuraServiceProvider = Provider<FloatingAuraService>((ref) {
  if (!Platform.isAndroid) {
    return const FloatingAuraStubChannel();
  }
  return FloatingAuraMethodChannel();
});

/// Whether the floating overlay is supported on this platform.
final floatingAuraSupportedProvider = Provider<bool>((ref) {
  final service = ref.watch(floatingAuraServiceProvider);
  return service.isSupported;
});

/// StateNotifier that drives the floating overlay lifecycle and
/// persists overlay position / expanded state to storage.
///
/// Integrates with the security policy (Step 7) by resolving
/// [ToolPermission.systemAlertWindow] via [SecurityPolicy] and then
/// checking the resolved permission via [PermissionService].
class FloatingAuraStateNotifier extends StateNotifier<FloatingAuraState> {
  FloatingAuraStateNotifier(
    this._service,
    this._localStorage,
    this._securityPolicy,
    this._permissionService,
  ) : super(const FloatingAuraState()) {
    _loadPersistedState();
  }

  final FloatingAuraService _service;
  final LocalStorageDataSource _localStorage;
  final SecurityPolicy _securityPolicy;
  final PermissionService _permissionService;

  /// Expose the service for testing.
  @visibleForTesting
  FloatingAuraService get service => _service;

  /// Loads persisted position / expanded state from storage.
  ///
  /// [LocalStorageDataSource.getString] and [getBool] are synchronous
  /// and return nullable values — no Result wrapping.
  void _loadPersistedState() {
    final xPos = _localStorage.getString(
      AppConstants.floatingAuraPositionXKey,
    );
    final yPos = _localStorage.getString(
      AppConstants.floatingAuraPositionYKey,
    );
    final isExpanded = _localStorage.getBool(
      AppConstants.floatingAuraIsExpandedKey,
    );
    final isVisible = _localStorage.getBool(
      AppConstants.floatingAuraIsVisibleKey,
    );

    final double? x = xPos != null ? double.tryParse(xPos) : null;
    final double? y = yPos != null ? double.tryParse(yPos) : null;

    if (x != null && y != null) {
      state = state.copyWith(
        position: FloatingAuraOverlayPosition(x: x, y: y),
      );
    }
    if (isExpanded != null) {
      state = state.copyWith(isExpanded: isExpanded);
    }

    // isVisible is informational only — we never auto-show the overlay
    // on app start. The user must explicitly trigger showOverlay.
    // We still persist it so the UI can reflect last known state.
    if (isVisible != null) {
      // Intentionally not applied to state.status — status reflects
      // the actual runtime overlay state, not a persisted flag.
    }
  }

  /// Persists the current position and expanded state to storage.
  ///
  /// [LocalStorageDataSource.setString] and [setBool] are async and
  /// return [Future<Result<bool, StorageFailure>>]. Failures are
  /// silently swallowed since position persistence is best-effort.
  Future<void> _persistState() async {
    final pos = state.position;
    if (pos != null) {
      await _localStorage.setString(
        AppConstants.floatingAuraPositionXKey,
        pos.x.toString(),
      );
      await _localStorage.setString(
        AppConstants.floatingAuraPositionYKey,
        pos.y.toString(),
      );
    }
    await _localStorage.setBool(
      AppConstants.floatingAuraIsExpandedKey,
      state.isExpanded,
    );
    await _localStorage.setBool(
      AppConstants.floatingAuraIsVisibleKey,
      state.isOverlayVisible,
    );
  }

  /// Checks overlay permission via the platform channel and updates
  /// [FloatingAuraState.hasPermission].
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      checkPermission() async {
    final result = await _service.hasPermission();
    return result.fold(
      onSuccess: (s) {
        // Preserve local state (position, isExpanded, etc.) that the
        // service has no knowledge of; only update hasPermission.
        state = state.copyWith(hasPermission: s.hasPermission);
        return Result.success(state);
      },
      onFailure: (f) {
        state = state.copyWith(
          status: FloatingAuraOverlayStatus.error,
          lastError: f.message,
        );
        return Result.failure(f);
      },
    );
  }

  /// Requests SYSTEM_ALERT_WINDOW permission through the security
  /// policy flow (Step 7 integration) then via the platform channel.
  ///
  /// First resolves [ToolPermission.systemAlertWindow] via
  /// [SecurityPolicy.resolvePermission], then checks the resolved
  /// [ph.Permission] via [PermissionService.isPermissionGranted].
  /// If the security policy blocks the permission (maps to null),
  /// returns a failure immediately.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      requestPermission() async {
    // Step 7 integration: resolve via security policy first.
    final resolved = _securityPolicy.resolvePermission(
      ToolPermission.systemAlertWindow,
    );
    if (resolved == null) {
      state = state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: 'SYSTEM_ALERT_WINDOW permission blocked by security policy',
      );
      return const Result.failure(
        FloatingAuraOverlayFailure(
          message:
              'SYSTEM_ALERT_WINDOW permission blocked by security policy',
          phase: FloatingAuraOverlayPhase.requestPermission,
        ),
      );
    }

    // Check if the resolved permission is already granted.
    final alreadyGranted =
        await _permissionService.isPermissionGranted(resolved);
    if (alreadyGranted) {
      state = state.copyWith(hasPermission: true);
      return Result.success(state);
    }

    // Delegate to the platform channel for the actual request.
    final result = await _service.requestPermission();
    return result.fold(
      onSuccess: (s) {
        state = s;
        return Result.success(state);
      },
      onFailure: (f) {
        state = state.copyWith(
          status: FloatingAuraOverlayStatus.error,
          lastError: f.message,
        );
        return Result.failure(f);
      },
    );
  }

  /// Shows the floating overlay at the given (or persisted) position.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      showOverlay() async {
    if (!state.hasPermission) {
      state = state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: 'SYSTEM_ALERT_WINDOW permission not granted',
      );
      return const Result.failure(
        FloatingAuraOverlayFailure(
          message: 'SYSTEM_ALERT_WINDOW permission not granted',
          phase: FloatingAuraOverlayPhase.showOverlay,
        ),
      );
    }

    final result = await _service.showOverlay(state.position);
    return result.fold(
      onSuccess: (s) {
        state = s;
        _persistState();
        return Result.success(state);
      },
      onFailure: (f) {
        state = state.copyWith(
          status: FloatingAuraOverlayStatus.error,
          lastError: f.message,
        );
        return Result.failure(f);
      },
    );
  }

  /// Hides the floating overlay.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hideOverlay() async {
    final result = await _service.hideOverlay();
    return result.fold(
      onSuccess: (s) {
        state = s;
        _persistState();
        return Result.success(state);
      },
      onFailure: (f) {
        state = state.copyWith(
          status: FloatingAuraOverlayStatus.error,
          lastError: f.message,
        );
        return Result.failure(f);
      },
    );
  }

  /// Updates overlay position (e.g. after drag) and persists.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      updatePosition(FloatingAuraOverlayPosition position) async {
    final result = await _service.updatePosition(position);
    return result.fold(
      onSuccess: (s) {
        state = s;
        _persistState();
        return Result.success(state);
      },
      onFailure: (f) {
        state = state.copyWith(
          lastError: f.message,
        );
        return Result.failure(f);
      },
    );
  }

  /// Toggles the panel between expanded and collapsed.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      togglePanel() async {
    final result = await _service.togglePanel();
    return result.fold(
      onSuccess: (s) {
        state = s;
        _persistState();
        return Result.success(state);
      },
      onFailure: (f) {
        state = state.copyWith(
          lastError: f.message,
        );
        return Result.failure(f);
      },
    );
  }

  /// Whether the overlay is currently visible.
  Future<Result<bool, FloatingAuraOverlayFailure>> isOverlayVisible() =>
      _service.isOverlayVisible();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// Provider for the [FloatingAuraStateNotifier].
///
/// Wires together [FloatingAuraService], [LocalStorageDataSource],
/// [SecurityPolicy], and [PermissionService] from their respective
/// Riverpod providers.
final floatingAuraStateProvider =
    StateNotifierProvider<FloatingAuraStateNotifier, FloatingAuraState>(
        (ref) {
  final service = ref.watch(floatingAuraServiceProvider);
  final localStorage = ref.watch(localStorageDataSourceProvider);
  final securityPolicy = ref.watch(securityPolicyProvider);
  final permissionService = ref.watch(permissionServiceProvider);
  return FloatingAuraStateNotifier(
    service,
    localStorage,
    securityPolicy,
    permissionService,
  );
});
