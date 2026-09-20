/// Hand-written fake [FloatingAuraService] for voice-screen engine tests.
library;

import 'dart:async';

import 'package:aura_assistant/core/floating_aura/floating_aura_service.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_state.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_overlay_position.dart';
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';

/// Configuration for [FakeFloatingAuraService].
class FakeOverlayConfig {
  /// If non-null, [showOverlay] returns this failure.
  final FloatingAuraOverlayFailure? showFailure;

  /// If non-null, [hideOverlay] returns this failure.
  final FloatingAuraOverlayFailure? hideFailure;

  /// If true, any method throws an unexpected exception.
  final bool shouldThrow;

  /// Delay before returning from show/hide.
  final Duration delay;

  /// Whether [requestPermission] simulates a granted permission.
  final bool grantPermission;

  /// If non-null, [requestPermission] returns this failure.
  final FloatingAuraOverlayFailure? permissionFailure;

  const FakeOverlayConfig({
    this.showFailure,
    this.hideFailure,
    this.shouldThrow = false,
    this.delay = Duration.zero,
    this.grantPermission = true,
    this.permissionFailure,
  });
}

/// A fake [FloatingAuraService] with configurable behaviour.
///
/// - Call [configure] before each test to set up expected outcomes.
/// - Tracks call counts and last arguments for assertions.
/// - Broadcasts state changes via [stateStream].
class FakeFloatingAuraService implements FloatingAuraService {
  FakeOverlayConfig _config = const FakeOverlayConfig();
  FloatingAuraState _state = const FloatingAuraState();
  final _stateController = StreamController<FloatingAuraState>.broadcast();

  /// Call counts for verification.
  int showOverlayCallCount = 0;
  int hideOverlayCallCount = 0;
  int requestPermissionCallCount = 0;
  int hasPermissionCallCount = 0;
  int openOverlaySettingsCallCount = 0;
  int updatePositionCallCount = 0;
  int togglePanelCallCount = 0;
  int isOverlayVisibleCallCount = 0;
  int disposeCallCount = 0;

  /// Last arguments for verification.
  FloatingAuraOverlayPosition? lastPosition;

  /// Configure the fake's behaviour.
  void configure(FakeOverlayConfig config) {
    _config = config;
  }

  @override
  FloatingAuraState get state => _state;

  Stream<FloatingAuraState> get stateStream => _stateController.stream;

  @override
  bool get isSupported => true;

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      requestPermission() async {
    requestPermissionCallCount++;

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake floating aura service');
    }

    if (_config.permissionFailure != null) {
      _setState(_state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: _config.permissionFailure!.message,
      ));
      return Result.failure(_config.permissionFailure!);
    }

    final granted = _config.grantPermission;
    _setState(_state.copyWith(
      status: FloatingAuraOverlayStatus.idle,
      hasPermission: granted,
      clearError: true,
    ));
    return Result.success(_state);
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      openOverlaySettings() async {
    openOverlaySettingsCallCount++;
    return Result.success(_state);
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hasPermission() async {
    hasPermissionCallCount++;
    return Result.success(_state);
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>> showOverlay(
    FloatingAuraOverlayPosition? position,
  ) async {
    showOverlayCallCount++;
    lastPosition = position;

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake floating aura service');
    }

    if (_config.showFailure != null) {
      _setState(_state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: _config.showFailure!.message,
      ));
      return Result.failure(_config.showFailure!);
    }

    _setState(_state.copyWith(
      status: FloatingAuraOverlayStatus.showing,
      position: position ?? FloatingAuraOverlayPosition.defaults,
    ));
    return Result.success(_state);
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>> hideOverlay()
      async {
    hideOverlayCallCount++;

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake floating aura service');
    }

    if (_config.hideFailure != null) {
      _setState(_state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: _config.hideFailure!.message,
      ));
      return Result.failure(_config.hideFailure!);
    }

    _setState(_state.copyWith(
      status: FloatingAuraOverlayStatus.idle,
      clearPosition: true,
    ));
    return Result.success(_state);
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      updatePosition(FloatingAuraOverlayPosition position) async {
    updatePositionCallCount++;
    lastPosition = position;
    _setState(_state.copyWith(position: position));
    return Result.success(_state);
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      togglePanel() async {
    togglePanelCallCount++;
    _setState(_state.copyWith(isExpanded: !_state.isExpanded));
    return Result.success(_state);
  }

  @override
  Future<Result<bool, FloatingAuraOverlayFailure>> isOverlayVisible() async {
    isOverlayVisibleCallCount++;
    return Result.success(_state.isOverlayVisible);
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await _stateController.close();
  }

  void _setState(FloatingAuraState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
