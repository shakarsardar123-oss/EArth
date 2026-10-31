/// subtitle_overlay_service.dart
/// AURA Assistant – Step 27: Live Kurdish Subtitle Overlay
///
/// Domain service contract for subtitle overlay management.
/// FAIL-CLOSED: any error → hidden, permission denied → denied.
/// Integrates with Step 24 overlay system and Step 26 integrity.
library;

import '../models/subtitle_entry.dart';
import '../models/subtitle_overlay_state.dart';

/// Verdict for overlay operations.
enum OverlayVerdict {
  allowed,
  denied,
  deniedPermission,
  deniedSafety,
  deniedOverlayUnavailable,
  unknown,
  ;

  bool get isAllowed => this == allowed;
  bool get isDenied =>
      this == denied ||
      this == deniedPermission ||
      this == deniedSafety ||
      this == deniedOverlayUnavailable ||
      this == unknown;
}

/// Abstract domain service for subtitle overlay.
/// Must be implemented by infrastructure adapters.
abstract class SubtitleOverlayService {
  /// Show the subtitle overlay.
  /// FAIL-CLOSED: any failure → denied.
  Future<OverlayVerdict> showOverlay();

  /// Hide the subtitle overlay.
  Future<SubtitleOverlayState> hideOverlay();

  /// Push a new subtitle entry onto the overlay.
  /// FAIL-CLOSED: denied/unknown → entry not shown, state unchanged.
  Future<OverlayVerdict> pushSubtitle(SubtitleEntry entry);

  /// Remove a subtitle entry by ID.
  Future<SubtitleOverlayState> removeSubtitle(String subtitleId);

  /// Clear all subtitle entries.
  Future<SubtitleOverlayState> clearAll();

  /// Get the current overlay state.
  /// FAIL-CLOSED: unknown → hidden.
  Future<SubtitleOverlayState> getCurrentState();

  /// Update overlay configuration.
  Future<SubtitleOverlayState> updateConfig({
    double? fontSize,
    double? backgroundOpacity,
    bool? showLowConfidence,
    int? maxVisibleEntries,
  });

  /// Stream of overlay state changes.
  /// FAIL-CLOSED: on error, emits denied state then closes.
  Stream<SubtitleOverlayState> stateStream();

  /// Check if overlay permission is granted.
  bool get hasPermission;

  /// Check if overlay is available on this device.
  bool get isAvailable;
}
