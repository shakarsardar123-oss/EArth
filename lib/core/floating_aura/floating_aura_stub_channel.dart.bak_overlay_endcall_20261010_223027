/// Stub implementation of [FloatingAuraService] for non-Android
/// platforms and test environments.
///
/// Every overlay operation returns a [FloatingAuraOverlayFailure]
/// since SYSTEM_ALERT_WINDOW is an Android-only feature.
/// [isSupported] is always false.
///
/// Pattern follows [ScreenCaptureStubChannel].
library;

import '../errors/result.dart';
import '../errors/failures.dart';
import 'floating_aura_state.dart';
import 'floating_aura_overlay_position.dart';
import 'floating_aura_service.dart';

/// No-op stub that always reports [isSupported] == false and returns
/// failures for every overlay operation.
class FloatingAuraStubChannel implements FloatingAuraService {
  const FloatingAuraStubChannel();

  @override
  FloatingAuraState get state => const FloatingAuraState();

  @override
  bool get isSupported => false;

  static FloatingAuraOverlayFailure _unsupported(
    FloatingAuraOverlayPhase phase,
  ) =>
      FloatingAuraOverlayFailure(
        message: 'Floating overlay is not supported on this platform',
        phase: phase,
      );

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      requestPermission() async =>
          Result.failure(_unsupported(FloatingAuraOverlayPhase.requestPermission));

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      openOverlaySettings() async => Result.failure(
            _unsupported(FloatingAuraOverlayPhase.openOverlaySettings),
          );

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hasPermission() async =>
          Result.failure(_unsupported(FloatingAuraOverlayPhase.requestPermission));

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>> showOverlay(
    FloatingAuraOverlayPosition? position,
  ) async =>
      Result.failure(_unsupported(FloatingAuraOverlayPhase.showOverlay));

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hideOverlay() async =>
          Result.failure(_unsupported(FloatingAuraOverlayPhase.hideOverlay));

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      updatePosition(FloatingAuraOverlayPosition position) async =>
          Result.failure(
            _unsupported(FloatingAuraOverlayPhase.updatePosition),
          );

  @override
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      togglePanel() async =>
          Result.failure(_unsupported(FloatingAuraOverlayPhase.togglePanel));

  @override
  Future<Result<bool, FloatingAuraOverlayFailure>> isOverlayVisible() async =>
      Result.failure(_unsupported(FloatingAuraOverlayPhase.showOverlay));

  @override
  Future<void> dispose() async {
    // No-op in stub.
  }
}
