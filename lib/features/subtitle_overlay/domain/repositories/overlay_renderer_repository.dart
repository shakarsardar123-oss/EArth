/// overlay_renderer_repository.dart
/// AURA Assistant – Step 27: Live Kurdish Subtitle Overlay
///
/// Domain repository contract for overlay rendering.
/// FAIL-CLOSED: any error → deny, unavailable → deny.
/// Integrates with Step 24 overlay/Step 26 integrity.
library;

import '../models/subtitle_entry.dart';
import '../models/subtitle_overlay_state.dart';

/// Result of an overlay rendering operation.
enum OverlayRenderResult {
  success,
  denied,
  deniedPermission,
  unavailable,
  error,
  unknown,
  ;

  bool get isSuccess => this == success;
  bool get isDenied =>
      this == denied ||
      this == deniedPermission ||
      this == unavailable ||
      this == error ||
      this == unknown;
}

/// Abstract repository for overlay rendering.
/// Infrastructure adapters must implement this interface EXACTLY.
abstract class OverlayRendererRepository {
  /// Request overlay permission.
  /// FAIL-CLOSED: denied/unknown → denied.
  Future<OverlayRenderResult> requestPermission();

  /// Check if overlay permission is granted.
  bool get hasPermission;

  /// Create or show the overlay window.
  /// FAIL-CLOSED: any failure → denied.
  Future<OverlayRenderResult> showOverlayWindow();

  /// Hide the overlay window.
  Future<OverlayRenderResult> hideOverlayWindow();

  /// Render a subtitle entry in the overlay.
  /// FAIL-CLOSED: denied/unknown → entry not rendered.
  Future<OverlayRenderResult> renderSubtitle(SubtitleEntry entry);

  /// Remove a subtitle entry from the overlay.
  Future<OverlayRenderResult> removeSubtitle(String subtitleId);

  /// Clear all subtitles from the overlay.
  Future<OverlayRenderResult> clearAllSubtitles();

  /// Get current overlay visibility.
  /// FAIL-CLOSED: unknown → hidden.
  Future<OverlayVisibility> getVisibility();

  /// Check if overlay rendering is available on this device.
  bool get isAvailable;

  /// Stream of overlay rendering events.
  Stream<SubtitleOverlayState> overlayStateStream();
}
