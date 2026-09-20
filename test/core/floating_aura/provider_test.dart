/// Tests for floating AURA overlay Riverpod providers — Step 11.
library;

import 'package:aura_assistant/core/errors/failures.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/constants/app_constants.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_service.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_state.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_overlay_position.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_provider.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_stub_channel.dart';
import 'package:aura_assistant/core/security/security_policy.dart';
import 'package:aura_assistant/core/security/security_providers.dart';
import 'package:aura_assistant/core/tools/tool_permission.dart';
import 'package:aura_assistant/core/permissions/permission_service.dart';
import 'package:aura_assistant/core/permissions/permission_provider.dart';
import 'package:aura_assistant/data/datasources/local_storage_data_source.dart';
import 'package:aura_assistant/presentation/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

// ═══════════════════════════════════════════════════════════════════
// Fake FloatingAuraService
// ═══════════════════════════════════════════════════════════════════

/// Configurable result for each service method.
class FakeFloatingAuraConfig {
  bool isSupported = true;
  FloatingAuraState state = const FloatingAuraState();

  Result<FloatingAuraState, FloatingAuraOverlayFailure>
      requestPermissionResult =
      Result.success(const FloatingAuraState(hasPermission: true));
  Result<FloatingAuraState, FloatingAuraOverlayFailure>
      openOverlaySettingsResult =
      Result.success(const FloatingAuraState());
  Result<FloatingAuraState, FloatingAuraOverlayFailure> hasPermissionResult =
      Result.success(const FloatingAuraState(hasPermission: true));
  Result<FloatingAuraState, FloatingAuraOverlayFailure> showOverlayResult =
      Result.success(const FloatingAuraState(
        status: FloatingAuraOverlayStatus.showing,
        hasPermission: true,
      ));
  Result<FloatingAuraState, FloatingAuraOverlayFailure> hideOverlayResult =
      Result.success(const FloatingAuraState(
        status: FloatingAuraOverlayStatus.idle,
        hasPermission: true,
      ));
  Result<FloatingAuraState, FloatingAuraOverlayFailure> updatePositionResult =
      Result.success(const FloatingAuraState(
        status: FloatingAuraOverlayStatus.showing,
        hasPermission: true,
        position: FloatingAuraOverlayPosition(x: 50.0, y: 200.0),
      ));
  Result<FloatingAuraState, FloatingAuraOverlayFailure> togglePanelResult =
      Result.success(const FloatingAuraState(
        status: FloatingAuraOverlayStatus.showing,
        hasPermission: true,
        isExpanded: true,
      ));
  Result<bool, FloatingAuraOverlayFailure> isOverlayVisibleResult =
      Result.success(true);
}

/// Hand-written fake for [FloatingAuraService].
///
/// Tracks method calls and returns configurable results.
class FakeFloatingAuraService implements FloatingAuraService {
  FakeFloatingAuraService([FakeFloatingAuraConfig? config])
      : _config = config ?? FakeFloatingAuraConfig();

  final FakeFloatingAuraConfig _config;

  // Call tracking
  int requestPermissionCallCount = 0;
  int openOverlaySettingsCallCount = 0;
  int hasPermissionCallCount = 0;
  int showOverlayCallCount = 0;
  int hideOverlayCallCount = 0;
  int updatePositionCallCount = 0;
  int togglePanelCallCount = 0;
  int isOverlayVisibleCallCount = 0;
  int disposeCallCount = 0;

  FloatingAuraOverlayPosition? lastUpdatePositionArg;
  FloatingAuraOverlayPosition? lastShowOverlayPositionArg;

  @override
  FloatingAuraState get state => _config.state;

  @override
  bool get isSupported => _config.isSupported;

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      requestPermission() async {
    requestPermissionCallCount++;
    return _config.requestPermissionResult;
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      openOverlaySettings() async {
    openOverlaySettingsCallCount++;
    return _config.openOverlaySettingsResult;
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hasPermission() async {
    hasPermissionCallCount++;
    return _config.hasPermissionResult;
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>> showOverlay(
    FloatingAuraOverlayPosition? position,
  ) async {
    showOverlayCallCount++;
    lastShowOverlayPositionArg = position;
    return _config.showOverlayResult;
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hideOverlay() async {
    hideOverlayCallCount++;
    return _config.hideOverlayResult;
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      updatePosition(FloatingAuraOverlayPosition position) async {
    updatePositionCallCount++;
    lastUpdatePositionArg = position;
    return _config.updatePositionResult;
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      togglePanel() async {
    togglePanelCallCount++;
    return _config.togglePanelResult;
  }

  @override
  Future<Result<bool, FloatingAuraOverlayFailure>> isOverlayVisible() async {
    isOverlayVisibleCallCount++;
    return _config.isOverlayVisibleResult;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Fake LocalStorageDataSource
// ═══════════════════════════════════════════════════════════════════

/// Hand-written fake for [LocalStorageDataSource].
///
/// Uses in-memory maps. Get operations are synchronous (nullable
/// returns); set/remove/clear are async returning
/// [Future<Result<bool, StorageFailure>>].
class FakeLocalStorageDataSource implements LocalStorageDataSource {
  final Map<String, String> _strings = {};
  final Map<String, bool> _bools = {};
  final Map<String, int> _ints = {};

  /// When true, set/remove/clear return failure instead of success.
  bool failOnWrite = false;

  // ── Generic get (sync, nullable) ──────────────────────────────

  @override
  String? getString(String key) => _strings[key];

  @override
  bool? getBool(String key) => _bools[key];

  @override
  int? getInt(String key) => _ints[key];

  // ── Generic set (async → Result) ─────────────────────────────

  @override
  Future<Result<bool, StorageFailure>> setString(
    String key,
    String value,
  ) async {
    if (failOnWrite) {
      return Result.failure(
        const StorageFailure(message: 'Fake write failure'),
      );
    }
    _strings[key] = value;
    return Result.success(true);
  }

  @override
  Future<Result<bool, StorageFailure>> setBool(
    String key,
    bool value,
  ) async {
    if (failOnWrite) {
      return Result.failure(
        const StorageFailure(message: 'Fake write failure'),
      );
    }
    _bools[key] = value;
    return Result.success(true);
  }

  @override
  Future<Result<bool, StorageFailure>> setInt(
    String key,
    int value,
  ) async {
    if (failOnWrite) {
      return Result.failure(
        const StorageFailure(message: 'Fake write failure'),
      );
    }
    _ints[key] = value;
    return Result.success(true);
  }

  // ── App-specific convenience getters ─────────────────────────

  @override
  String get themeMode =>
      getString(AppConstants.themeKey) ?? 'dark';

  @override
  Future<Result<bool, StorageFailure>> setThemeMode(String mode) =>
      setString(AppConstants.themeKey, mode);

  @override
  String get localeCode =>
      getString(AppConstants.localeKey) ?? 'ku';

  @override
  Future<Result<bool, StorageFailure>> setLocaleCode(String code) =>
      setString(AppConstants.localeKey, code);

  @override
  bool get onboardingCompleted =>
      getBool(AppConstants.onboardingKey) ?? false;

  @override
  Future<Result<bool, StorageFailure>> setOnboardingCompleted(bool value) =>
      setBool(AppConstants.onboardingKey, value);

  @override
  String get activeAgentId =>
      getString(AppConstants.activeAgentKey) ?? 'aura';

  @override
  Future<Result<bool, StorageFailure>> setActiveAgentId(String id) =>
      setString(AppConstants.activeAgentKey, id);

  // ── Remove / Clear (async → Result) ──────────────────────────

  @override
  Future<Result<bool, StorageFailure>> remove(String key) async {
    if (failOnWrite) {
      return Result.failure(
        const StorageFailure(message: 'Fake write failure'),
      );
    }
    _strings.remove(key);
    _bools.remove(key);
    _ints.remove(key);
    return Result.success(true);
  }

  @override
  Future<Result<bool, StorageFailure>> clear() async {
    if (failOnWrite) {
      return Result.failure(
        const StorageFailure(message: 'Fake write failure'),
      );
    }
    _strings.clear();
    _bools.clear();
    _ints.clear();
    return Result.success(true);
  }

  // ── Test helpers ─────────────────────────────────────────────

  /// Pre-populate a string value for testing persisted state load.
  void presetString(String key, String value) {
    _strings[key] = value;
  }

  /// Pre-populate a bool value for testing persisted state load.
  void presetBool(String key, bool value) {
    _bools[key] = value;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Fake SecurityPolicy
// ═══════════════════════════════════════════════════════════════════

/// Hand-written fake for [SecurityPolicy].
///
/// Allows overriding the permission map so tests can simulate
/// a blocked permission (maps to null).
class FakeSecurityPolicy extends SecurityPolicy {
  FakeSecurityPolicy({
    Map<ToolPermission, ph.Permission?>? permissionMap,
  }) : super(
          permissionMap: permissionMap ??
              {
                ToolPermission.systemAlertWindow: ph.Permission.systemAlertWindow,
              },
        );
}

// ═══════════════════════════════════════════════════════════════════
// Fake PermissionService
// ═══════════════════════════════════════════════════════════════════

/// Hand-written fake for [PermissionService].
///
/// Allows configuring [isPermissionGranted] and tracking calls.
class FakePermissionService extends PermissionService {
  FakePermissionService({
    this.isPermissionGrantedResult = false,
  });

  final bool isPermissionGrantedResult;

  int isPermissionGrantedCallCount = 0;
  ph.Permission? lastIsPermissionGrantedArg;

  int requestPermissionCallCount = 0;
  ph.Permission? lastRequestPermissionArg;

  @override
  Future<bool> isPermissionGranted(ph.Permission permission) async {
    isPermissionGrantedCallCount++;
    lastIsPermissionGrantedArg = permission;
    return isPermissionGrantedResult;
  }

  @override
  Future<Result<bool, PermissionFailure>> requestPermission(
    ph.Permission permission,
  ) async {
    requestPermissionCallCount++;
    lastRequestPermissionArg = permission;
    if (isPermissionGrantedResult) {
      return Result.success(true);
    }
    return Result.failure(PermissionFailure(
      message: 'Permission ${permission.toString()} denied',
      code: 'PERMISSION_DENIED',
      permission: permission.toString(),
    ));
  }

  @override
  Future<bool> isPermissionPermanentlyDenied(ph.Permission permission) async {
    return false;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<Map<ph.Permission, bool>> requestAllRequiredPermissions() async {
    return {};
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

void main() {
  late ProviderContainer container;
  late FakeFloatingAuraService fakeService;
  late FakeLocalStorageDataSource fakeLocalStorage;

  /// Creates a [ProviderContainer] with all providers overridden
  /// to use fakes.
  ProviderContainer makeContainer({
    FakeFloatingAuraConfig? serviceConfig,
    FakeLocalStorageDataSource? localStorage,
    FakeSecurityPolicy? securityPolicy,
    FakePermissionService? permissionService,
  }) {
    final cfg = serviceConfig ?? FakeFloatingAuraConfig();
    final svc = FakeFloatingAuraService(cfg);
    fakeService = svc;

    final ls = localStorage ?? FakeLocalStorageDataSource();
    fakeLocalStorage = ls;

    final sp = securityPolicy ??
        FakeSecurityPolicy(
          permissionMap: {
            ToolPermission.systemAlertWindow: ph.Permission.systemAlertWindow,
          },
        );

    final ps = permissionService ??
        FakePermissionService(isPermissionGrantedResult: false);

    return ProviderContainer(overrides: [
      floatingAuraServiceProvider.overrideWithValue(svc),
      localStorageDataSourceProvider.overrideWithValue(ls),
      securityPolicyProvider.overrideWithValue(sp),
      permissionServiceProvider.overrideWithValue(ps),
    ]);
  }

  setUp(() {
    container = makeContainer();
  });

  tearDown(() async {
    // Flush any fire-and-forget async work (e.g. _persistState)
    // before disposing the container to avoid post-dispose errors.
    await Future.delayed(const Duration(milliseconds: 50));
    container.dispose();
  });

  // ───────────────────────────────────────────────────────────────
  // floatingAuraServiceProvider
  // ───────────────────────────────────────────────────────────────
  group('floatingAuraServiceProvider', () {
    test('can be overridden with fake', () {
      final service = container.read(floatingAuraServiceProvider);
      expect(service, same(fakeService));
    });

    test('provides a FloatingAuraService', () {
      final service = container.read(floatingAuraServiceProvider);
      expect(service, isA<FloatingAuraService>());
    });
  });

  // ───────────────────────────────────────────────────────────────
  // floatingAuraSupportedProvider
  // ───────────────────────────────────────────────────────────────
  group('floatingAuraSupportedProvider', () {
    test('returns true when service is supported', () {
      final supported = container.read(floatingAuraSupportedProvider);
      expect(supported, true);
    });

    test('returns false when service is not supported', () {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()..isSupported = false,
      );
      final supported = container.read(floatingAuraSupportedProvider);
      expect(supported, false);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // floatingAuraStateProvider — initial state
  // ───────────────────────────────────────────────────────────────
  group('floatingAuraStateProvider initial state', () {
    test('defaults to idle with no permission', () {
      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.idle);
      expect(state.hasPermission, false);
      expect(state.isExpanded, false);
      expect(state.position, isNull);
      expect(state.lastError, isNull);
    });

    test('notifier exposes service reference', () {
      final notifier = container.read(floatingAuraStateProvider.notifier);
      expect(notifier.service, same(fakeService));
    });
  });

  // ───────────────────────────────────────────────────────────────
  // _loadPersistedState
  // ───────────────────────────────────────────────────────────────
  group('_loadPersistedState', () {
    test('restores position from storage', () {
      final ls = FakeLocalStorageDataSource();
      ls.presetString(
        AppConstants.floatingAuraPositionXKey,
        '42.5',
      );
      ls.presetString(
        AppConstants.floatingAuraPositionYKey,
        '137.0',
      );

      container.dispose();
      container = makeContainer(localStorage: ls);

      final state = container.read(floatingAuraStateProvider);
      expect(state.position, isNotNull);
      expect(state.position!.x, 42.5);
      expect(state.position!.y, 137.0);
    });

    test('does not restore position when x is missing', () {
      final ls = FakeLocalStorageDataSource();
      ls.presetString(
        AppConstants.floatingAuraPositionYKey,
        '137.0',
      );

      container.dispose();
      container = makeContainer(localStorage: ls);

      final state = container.read(floatingAuraStateProvider);
      expect(state.position, isNull);
    });

    test('does not restore position when y is missing', () {
      final ls = FakeLocalStorageDataSource();
      ls.presetString(
        AppConstants.floatingAuraPositionXKey,
        '42.5',
      );

      container.dispose();
      container = makeContainer(localStorage: ls);

      final state = container.read(floatingAuraStateProvider);
      expect(state.position, isNull);
    });

    test('does not restore position when x is unparseable', () {
      final ls = FakeLocalStorageDataSource();
      ls.presetString(
        AppConstants.floatingAuraPositionXKey,
        'not-a-number',
      );
      ls.presetString(
        AppConstants.floatingAuraPositionYKey,
        '137.0',
      );

      container.dispose();
      container = makeContainer(localStorage: ls);

      final state = container.read(floatingAuraStateProvider);
      expect(state.position, isNull);
    });

    test('restores isExpanded from storage', () {
      final ls = FakeLocalStorageDataSource();
      ls.presetBool(
        AppConstants.floatingAuraIsExpandedKey,
        true,
      );

      container.dispose();
      container = makeContainer(localStorage: ls);

      final state = container.read(floatingAuraStateProvider);
      expect(state.isExpanded, true);
    });

    test('isExpanded defaults to false when not stored', () {
      final state = container.read(floatingAuraStateProvider);
      expect(state.isExpanded, false);
    });

    test('isVisible is NOT applied to status', () {
      // Even if isVisible is persisted as true, the status should
      // remain idle — the user must explicitly call showOverlay.
      final ls = FakeLocalStorageDataSource();
      ls.presetBool(
        AppConstants.floatingAuraIsVisibleKey,
        true,
      );

      container.dispose();
      container = makeContainer(localStorage: ls);

      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.idle);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // checkPermission
  // ───────────────────────────────────────────────────────────────
  group('checkPermission', () {
    test('succeeds and updates state', () async {
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.checkPermission();

      expect(result.isSuccess, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.hasPermission, true);
      expect(fakeService.hasPermissionCallCount, 1);
    });

    test('fails and sets error status', () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..hasPermissionResult = Result.failure(
            const FloatingAuraOverlayFailure(
              message: 'Permission check failed',
              phase: FloatingAuraOverlayPhase.requestPermission,
            ),
          ),
      );

      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.checkPermission();

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.error);
      expect(state.lastError, 'Permission check failed');
    });
  });

  // ───────────────────────────────────────────────────────────────
  // requestPermission
  // ───────────────────────────────────────────────────────────────
  group('requestPermission', () {
    test('returns failure when security policy blocks permission',
        () async {
      container.dispose();
      container = makeContainer(
        securityPolicy: FakeSecurityPolicy(
          permissionMap: {
            // systemAlertWindow maps to null → blocked
            ToolPermission.systemAlertWindow: null,
          },
        ),
      );

      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.requestPermission();

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.error);
      expect(
        state.lastError,
        'SYSTEM_ALERT_WINDOW permission blocked by security policy',
      );
      // The service should NOT be called since policy blocked it.
      expect(fakeService.requestPermissionCallCount, 0);
    });

    test('returns success when permission is already granted',
        () async {
      container.dispose();
      container = makeContainer(
        permissionService:
            FakePermissionService(isPermissionGrantedResult: true),
      );

      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.requestPermission();

      expect(result.isSuccess, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.hasPermission, true);
      // The service should NOT be called since already granted.
      expect(fakeService.requestPermissionCallCount, 0);
    });

    test('delegates to service when permission not yet granted',
        () async {
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.requestPermission();

      expect(result.isSuccess, true);
      expect(fakeService.requestPermissionCallCount, 1);
    });

    test('returns failure when service requestPermission fails',
        () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..requestPermissionResult = Result.failure(
            const FloatingAuraOverlayFailure(
              message: 'User denied overlay permission',
              phase: FloatingAuraOverlayPhase.requestPermission,
            ),
          ),
      );

      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.requestPermission();

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.error);
      expect(state.lastError, 'User denied overlay permission');
    });
  });

  // ───────────────────────────────────────────────────────────────
  // showOverlay
  // ───────────────────────────────────────────────────────────────
  group('showOverlay', () {
    test('returns failure when permission not granted', () async {
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.showOverlay();

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.error);
      expect(
        state.lastError,
        'SYSTEM_ALERT_WINDOW permission not granted',
      );
      // The service should NOT be called.
      expect(fakeService.showOverlayCallCount, 0);
    });

    test('succeeds and updates state when permission is granted',
        () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..hasPermissionResult =
              Result.success(const FloatingAuraState(hasPermission: true)),
      );

      // First, set hasPermission = true in state via checkPermission.
      var notifier = container.read(floatingAuraStateProvider.notifier);
      await notifier.checkPermission();

      final stateBefore = container.read(floatingAuraStateProvider);
      expect(stateBefore.hasPermission, true);

      // Now showOverlay should delegate to service.
      notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.showOverlay();

      expect(result.isSuccess, true);
      expect(fakeService.showOverlayCallCount, 1);
    });

    test('passes current position to service showOverlay', () async {
      final ls = FakeLocalStorageDataSource();
      ls.presetString(
        AppConstants.floatingAuraPositionXKey,
        '42.0',
      );
      ls.presetString(
        AppConstants.floatingAuraPositionYKey,
        '200.0',
      );

      container.dispose();
      container = makeContainer(
        localStorage: ls,
        serviceConfig: FakeFloatingAuraConfig()
          ..hasPermissionResult =
              Result.success(const FloatingAuraState(hasPermission: true)),
      );

      // Set hasPermission.
      var notifier = container.read(floatingAuraStateProvider.notifier);
      await notifier.checkPermission();

      notifier = container.read(floatingAuraStateProvider.notifier);
      await notifier.showOverlay();

      expect(fakeService.lastShowOverlayPositionArg, isNotNull);
      expect(fakeService.lastShowOverlayPositionArg!.x, 42.0);
      expect(fakeService.lastShowOverlayPositionArg!.y, 200.0);
    });

    test('returns failure and sets error when service fails',
        () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..hasPermissionResult =
              Result.success(const FloatingAuraState(hasPermission: true))
          ..showOverlayResult = Result.failure(
            const FloatingAuraOverlayFailure(
              message: 'Overlay show failed',
              phase: FloatingAuraOverlayPhase.showOverlay,
            ),
          ),
      );

      // Grant permission first.
      var notifier = container.read(floatingAuraStateProvider.notifier);
      await notifier.checkPermission();

      notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.showOverlay();

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.error);
      expect(state.lastError, 'Overlay show failed');
    });
  });

  // ───────────────────────────────────────────────────────────────
  // hideOverlay
  // ───────────────────────────────────────────────────────────────
  group('hideOverlay', () {
    test('succeeds and updates state', () async {
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.hideOverlay();

      expect(result.isSuccess, true);
      expect(fakeService.hideOverlayCallCount, 1);
    });

    test('returns failure and sets error when service fails',
        () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..hideOverlayResult = Result.failure(
            const FloatingAuraOverlayFailure(
              message: 'Hide overlay failed',
              phase: FloatingAuraOverlayPhase.hideOverlay,
            ),
          ),
      );

      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.hideOverlay();

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.status, FloatingAuraOverlayStatus.error);
      expect(state.lastError, 'Hide overlay failed');
    });
  });

  // ───────────────────────────────────────────────────────────────
  // updatePosition
  // ───────────────────────────────────────────────────────────────
  group('updatePosition', () {
    test('delegates to service and persists state', () async {
      final pos = FloatingAuraOverlayPosition(x: 99.0, y: 188.0);
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.updatePosition(pos);

      expect(result.isSuccess, true);
      expect(fakeService.updatePositionCallCount, 1);
      expect(fakeService.lastUpdatePositionArg, pos);

      // _persistState is fire-and-forget; wait for it to complete
      // before checking the fake storage.
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify persistence was called (strings for x/y, bools for
      // isExpanded and isVisible).
      expect(
        fakeLocalStorage.getString(AppConstants.floatingAuraPositionXKey),
        '50.0', // from the fake service's updatePositionResult state
      );
      expect(
        fakeLocalStorage.getString(AppConstants.floatingAuraPositionYKey),
        '200.0',
      );
    });

    test('returns failure when service fails', () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..updatePositionResult = Result.failure(
            const FloatingAuraOverlayFailure(
              message: 'Position update failed',
              phase: FloatingAuraOverlayPhase.updatePosition,
            ),
          ),
      );

      final pos = FloatingAuraOverlayPosition(x: 10.0, y: 20.0);
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.updatePosition(pos);

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.lastError, 'Position update failed');
    });

    test('swallows persistence failures silently', () async {
      final ls = FakeLocalStorageDataSource()..failOnWrite = true;

      container.dispose();
      container = makeContainer(localStorage: ls);

      final pos = FloatingAuraOverlayPosition(x: 10.0, y: 20.0);
      final notifier = container.read(floatingAuraStateProvider.notifier);
      // Should not throw even though writes fail.
      final result = await notifier.updatePosition(pos);
      expect(result.isSuccess, true);

      // Allow fire-and-forget _persistState to complete so it
      // doesn't collide with tearDown's container.dispose().
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });

  // ───────────────────────────────────────────────────────────────
  // togglePanel
  // ───────────────────────────────────────────────────────────────
  group('togglePanel', () {
    test('delegates to service and updates state', () async {
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.togglePanel();

      expect(result.isSuccess, true);
      expect(fakeService.togglePanelCallCount, 1);
      final state = container.read(floatingAuraStateProvider);
      expect(state.isExpanded, true); // from config
    });

    test('returns failure and sets lastError when service fails',
        () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..togglePanelResult = Result.failure(
            const FloatingAuraOverlayFailure(
              message: 'Panel toggle failed',
              phase: FloatingAuraOverlayPhase.togglePanel,
            ),
          ),
      );

      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.togglePanel();

      expect(result.isFailure, true);
      final state = container.read(floatingAuraStateProvider);
      expect(state.lastError, 'Panel toggle failed');
    });
  });

  // ───────────────────────────────────────────────────────────────
  // isOverlayVisible
  // ───────────────────────────────────────────────────────────────
  group('isOverlayVisible', () {
    test('delegates to service and returns result', () async {
      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.isOverlayVisible();

      expect(result.isSuccess, true);
      result.when(
        success: (visible) => expect(visible, true),
        failure: (_) => fail('Expected success'),
      );
      expect(fakeService.isOverlayVisibleCallCount, 1);
    });

    test('returns failure when service fails', () async {
      container.dispose();
      container = makeContainer(
        serviceConfig: FakeFloatingAuraConfig()
          ..isOverlayVisibleResult = Result.failure(
            const FloatingAuraOverlayFailure(
              message: 'Visibility check failed',
              phase: FloatingAuraOverlayPhase.showOverlay,
            ),
          ),
      );

      final notifier = container.read(floatingAuraStateProvider.notifier);
      final result = await notifier.isOverlayVisible();

      expect(result.isFailure, true);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // dispose
  // ───────────────────────────────────────────────────────────────
  group('dispose', () {
    test('calls service dispose', () async {
      // Use a second container so dispose is independent of tearDown.
      final container2 = makeContainer();
      // Ensure the notifier is created so its dispose runs.
      container2.read(floatingAuraStateProvider.notifier);
      final svc = container2.read(floatingAuraServiceProvider)
          as FakeFloatingAuraService;

      // Disposing the container triggers auto-dispose which calls
      // the notifier's dispose(), which in turn calls service.dispose().
      // Do NOT call notifier.dispose() manually — StateNotifier.dispose
      // is not idempotent (StreamController.close() on a closed
      // controller throws).
      container2.dispose();

      expect(svc.disposeCallCount, 1);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // FloatingAuraStubChannel integration
  // ───────────────────────────────────────────────────────────────
  group('FloatingAuraStubChannel', () {
    test('is not supported', () {
      const stub = FloatingAuraStubChannel();
      expect(stub.isSupported, false);
    });

    test('all methods return failure', () async {
      const stub = FloatingAuraStubChannel();

      final rp = await stub.requestPermission();
      expect(rp.isFailure, true);

      final os = await stub.openOverlaySettings();
      expect(os.isFailure, true);

      final hp = await stub.hasPermission();
      expect(hp.isFailure, true);

      final so = await stub.showOverlay(null);
      expect(so.isFailure, true);

      final ho = await stub.hideOverlay();
      expect(ho.isFailure, true);

      final up = await stub.updatePosition(
        const FloatingAuraOverlayPosition(x: 0, y: 0),
      );
      expect(up.isFailure, true);

      final tp = await stub.togglePanel();
      expect(tp.isFailure, true);

      final iv = await stub.isOverlayVisible();
      expect(iv.isFailure, true);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // SecurityPolicy + PermissionService integration
  // ───────────────────────────────────────────────────────────────
  group('SecurityPolicy integration', () {
    test('resolvePermission returns correct permission for systemAlertWindow',
        () {
      final policy = FakeSecurityPolicy();
      final resolved =
          policy.resolvePermission(ToolPermission.systemAlertWindow);
      expect(resolved, ph.Permission.systemAlertWindow);
    });

    test('resolvePermission returns null when blocked', () {
      final policy = FakeSecurityPolicy(
        permissionMap: {
          ToolPermission.systemAlertWindow: null,
        },
      );
      final resolved =
          policy.resolvePermission(ToolPermission.systemAlertWindow);
      expect(resolved, isNull);
    });

    test('PermissionService.isPermissionGranted is called with resolved permission',
        () async {
      final ps = FakePermissionService(isPermissionGrantedResult: true);
      container.dispose();
      container = makeContainer(permissionService: ps);

      final notifier = container.read(floatingAuraStateProvider.notifier);
      await notifier.requestPermission();

      expect(ps.isPermissionGrantedCallCount, 1);
      expect(
        ps.lastIsPermissionGrantedArg,
        ph.Permission.systemAlertWindow,
      );
    });
  });
}
