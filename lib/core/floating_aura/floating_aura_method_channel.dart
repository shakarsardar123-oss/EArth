/// Android platform-channel implementation of [FloatingAuraService].
///
/// Uses a [MethodChannel] for overlay control operations:
/// requesting permission, showing/hiding the overlay, updating
/// position, and toggling the panel.
///
/// On non-Android platforms this class is never registered — see
/// [FloatingAuraStubChannel] instead.
library;

import 'package:flutter/services.dart'
    show MethodChannel, PlatformException;

import '../errors/result.dart';
import '../errors/failures.dart';
import 'floating_aura_state.dart';
import 'floating_texo_overlay_position.dart';
import 'floating_aura_service.dart';
import 'floating_aura_constants.dart';

/// MethodChannel implementation of [FloatingAuraService] for Android.
class FloatingAuraMethodChannel implements FloatingAuraService {
  FloatingAuraMethodChannel({
    MethodChannel? methodChannel,
  }) : _methodChannel = methodChannel ??
            const MethodChannel(floatingAuraMethodChannelName);

  final MethodChannel _methodChannel;

  FloatingAuraState _state = const FloatingAuraState();

  @override
  FloatingAuraState get state => _state;

  @override
  bool get isSupported => true; // Android supports SYSTEM_ALERT_WINDOW.

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      requestPermission() async {
    _state = _state.copyWith(
      status: FloatingAuraOverlayStatus.requestingPermission,
    );

    try {
      final result = await _methodChannel.invokeMethod<Map>(
        FloatingAuraMethodNames.requestPermission,
      );

      if (result == null) {
        _state = _state.copyWith(
          status: FloatingAuraOverlayStatus.error,
          lastError: 'Permission request returned null',
        );
        return const Result.failure(
          FloatingAuraOverlayFailure(
            message: 'Permission request returned null',
            phase: FloatingAuraOverlayPhase.requestPermission,
          ),
        );
      }

      final granted = result['granted'] as bool? ?? false;
      _state = _state.copyWith(
        status: granted
            ? FloatingAuraOverlayStatus.idle
            : FloatingAuraOverlayStatus.error,
        hasPermission: granted,
        lastError: granted ? null : 'SYSTEM_ALERT_WINDOW permission denied',
        clearError: granted,
      );

      if (!granted) {
        return const Result.failure(
          FloatingAuraOverlayFailure(
            message: 'SYSTEM_ALERT_WINDOW permission denied',
            phase: FloatingAuraOverlayPhase.requestPermission,
          ),
        );
      }

      return Result.success(_state);
    } on PlatformException catch (e) {
      _state = _state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: e.message ?? e.code,
      );
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Platform error: ${e.code}',
          phase: FloatingAuraOverlayPhase.requestPermission,
        ),
      );
    }
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      openOverlaySettings() async {
    try {
      await _methodChannel.invokeMethod<void>(
        FloatingAuraMethodNames.openOverlaySettings,
      );

      // After opening settings, we don't know the permission result yet.
      // The caller should check hasPermission() after the user returns.
      return Result.success(_state);
    } on PlatformException catch (e) {
      _state = _state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: e.message ?? e.code,
      );
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Failed to open overlay settings: ${e.code}',
          phase: FloatingAuraOverlayPhase.openOverlaySettings,
        ),
      );
    }
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hasPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        FloatingAuraMethodNames.hasPermission,
      );

      if (result == null) {
        return const Result.failure(
          FloatingAuraOverlayFailure(
            message: 'hasPermission returned null',
            phase: FloatingAuraOverlayPhase.requestPermission,
          ),
        );
      }

      final granted = result['granted'] as bool? ?? false;
      _state = _state.copyWith(hasPermission: granted);
      return Result.success(_state);
    } on PlatformException catch (e) {
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Failed to check permission: ${e.code}',
          phase: FloatingAuraOverlayPhase.requestPermission,
        ),
      );
    }
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>> showOverlay(
    FloatingAuraOverlayPosition? position,
  ) async {
    if (!_state.hasPermission) {
      _state = _state.copyWith(
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

    final effectivePosition = position ?? _state.resolvedPosition;

    try {
      final result = await _methodChannel.invokeMethod<Map>(
        FloatingAuraMethodNames.showOverlay,
        effectivePosition.toMap(),
      );

      if (result == null) {
        _state = _state.copyWith(
          status: FloatingAuraOverlayStatus.error,
          lastError: 'Show overlay returned null',
        );
        return const Result.failure(
          FloatingAuraOverlayFailure(
            message: 'Show overlay returned null',
            phase: FloatingAuraOverlayPhase.showOverlay,
          ),
        );
      }

      final shown = result['shown'] as bool? ?? false;
      if (!shown) {
        final errorMsg = result['error'] as String? ??
            'Overlay view setup failed';
        _state = _state.copyWith(
          status: FloatingAuraOverlayStatus.error,
          lastError: errorMsg,
        );
        return Result.failure(
          FloatingAuraOverlayFailure(
            message: errorMsg,
            phase: FloatingAuraOverlayPhase.setupOverlayView,
          ),
        );
      }

      _state = _state.copyWith(
        status: FloatingAuraOverlayStatus.showing,
        clearError: true,
        position: effectivePosition,
      );

      return Result.success(_state);
    } on PlatformException catch (e) {
      _state = _state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: e.message ?? e.code,
      );
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Platform error: ${e.code}',
          phase: FloatingAuraOverlayPhase.setupOverlayView,
        ),
      );
    }
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hideOverlay() async {
    if (_state.status == FloatingAuraOverlayStatus.idle) {
      return Result.success(_state);
    }

    _state = _state.copyWith(status: FloatingAuraOverlayStatus.hiding);

    try {
      await _methodChannel.invokeMethod<void>(
        FloatingAuraMethodNames.hideOverlay,
      );
    } on PlatformException catch (e) {
      // Even if the platform call fails, we still clear local state.
      _state = _state.copyWith(
        status: FloatingAuraOverlayStatus.error,
        lastError: e.message ?? 'Hide failed: ${e.code}',
      );
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Hide failed: ${e.code}',
          phase: FloatingAuraOverlayPhase.hideOverlay,
        ),
      );
    }

    _state = _state.copyWith(
      status: FloatingAuraOverlayStatus.idle,
      clearError: true,
    );
    return Result.success(_state);
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      updatePosition(FloatingAuraOverlayPosition position) async {
    try {
      await _methodChannel.invokeMethod<void>(
        FloatingAuraMethodNames.updatePosition,
        position.toMap(),
      );

      _state = _state.copyWith(position: position);
      return Result.success(_state);
    } on PlatformException catch (e) {
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Position update failed: ${e.code}',
          phase: FloatingAuraOverlayPhase.updatePosition,
        ),
      );
    }
  }

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      togglePanel() async {
    if (!_state.canTogglePanel) {
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: 'Cannot toggle panel: overlay not visible '
              '(status: ${_state.status})',
          phase: FloatingAuraOverlayPhase.togglePanel,
        ),
      );
    }

    try {
      final result = await _methodChannel.invokeMethod<Map>(
        FloatingAuraMethodNames.togglePanel,
      );

      if (result == null) {
        return const Result.failure(
          FloatingAuraOverlayFailure(
            message: 'Toggle panel returned null',
            phase: FloatingAuraOverlayPhase.togglePanel,
          ),
        );
      }

      final expanded = result['isExpanded'] as bool? ?? !_state.isExpanded;
      _state = _state.copyWith(isExpanded: expanded);

      return Result.success(_state);
    } on PlatformException catch (e) {
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Toggle panel failed: ${e.code}',
          phase: FloatingAuraOverlayPhase.togglePanel,
        ),
      );
    }
  }

  @override
  Future<Result<bool, FloatingAuraOverlayFailure>> isOverlayVisible() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        FloatingAuraMethodNames.isOverlayVisible,
      );

      if (result == null) {
        return const Result.failure(
          FloatingAuraOverlayFailure(
            message: 'isOverlayVisible returned null',
            phase: FloatingAuraOverlayPhase.showOverlay,
          ),
        );
      }

      final visible = result['visible'] as bool? ?? false;
      return Result.success(visible);
    } on PlatformException catch (e) {
      return Result.failure(
        FloatingAuraOverlayFailure(
          message: e.message ?? 'Visibility check failed: ${e.code}',
          phase: FloatingAuraOverlayPhase.showOverlay,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_state.status != FloatingAuraOverlayStatus.idle) {
      await hideOverlay();
    }
  }
}
