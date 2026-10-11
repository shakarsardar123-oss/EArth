/// Abstract interface for the AURA floating overlay service.
///
/// Defines the contract for showing/hiding a SYSTEM_ALERT_WINDOW
/// overlay, managing overlay permission, toggling the panel,
/// and persisting overlay position. The concrete implementation
/// uses Android platform channels (MethodChannel) to drive
/// WindowManager overlay and a foreground service on the native side.
///
/// Pattern follows [ScreenCaptureService]: abstract interface +
/// platform impl + stub impl for non-Android / test environments.
library;

import '../errors/result.dart';
import '../errors/failures.dart';
import 'floating_aura_state.dart';
import 'floating_aura_overlay_position.dart';

/// Contract for platform-level floating overlay operations.
///
/// Every method returns [Result] so that callers never need to catch
/// platform exceptions — errors are always represented as
/// [FloatingAuraOverlayFailure] values.
abstract class FloatingAuraService {
  /// Current state of the overlay subsystem.
  FloatingAuraState get state;

  /// Whether the current platform supports floating overlay
  /// (SYSTEM_ALERT_WINDOW).
  bool get isSupported;

  /// Requests the SYSTEM_ALERT_WINDOW permission.
  ///
  /// On Android 6.0+ this opens the system overlay settings
  /// screen where the user must manually enable the permission.
  ///
  /// Returns [Result.success] with the updated [FloatingAuraState]
  /// if the permission was granted, or [Result.failure] with a
  /// [FloatingAuraOverlayFailure] if the user denied it.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      requestPermission();

  /// Opens the system overlay settings screen.
  ///
  /// Useful when [requestPermission] cannot directly grant the
  /// permission and the user needs to navigate to settings manually.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      openOverlaySettings();

  /// Checks whether SYSTEM_ALERT_WINDOW permission is currently granted.
  ///
  /// Returns [Result.success] with updated state where
  /// [FloatingAuraState.hasPermission] reflects the current status.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      hasPermission();

  /// Shows the floating overlay button on screen.
  ///
  /// The overlay starts in collapsed (button-only) mode at the given
  /// [position]. If [position] is null, the last persisted or default
  /// position is used.
  ///
  /// Requires SYSTEM_ALERT_WINDOW permission — call [requestPermission]
  /// or [hasPermission] first.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>> showOverlay(
    FloatingAuraOverlayPosition? position,
  );

  /// Hides the floating overlay button and panel.
  ///
  /// Returns the updated [FloatingAuraState] with status → idle.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>> hideOverlay();

  /// Updates the overlay position (e.g. after drag).
  ///
  /// Persists the position via platform channel so the native
  /// WindowManager can update LayoutParams.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      updatePosition(FloatingAuraOverlayPosition position);

  /// Toggles the overlay panel between expanded and collapsed.
  ///
  /// When expanded, a full panel is shown next to the button.
  /// When collapsed, only the floating button is visible.
  Future<Result<FloatingAuraState, FloatingAuraOverlayFailure>>
      togglePanel();

  /// Whether the overlay is currently visible on screen.
  Future<Result<bool, FloatingAuraOverlayFailure>> isOverlayVisible();

  /// Releases all resources and hides the overlay.
  ///
  /// Call in widget dispose / app lifecycle pause to ensure
  /// the foreground service is stopped even if [hideOverlay] was
  /// not called.
  Future<void> dispose();
}
