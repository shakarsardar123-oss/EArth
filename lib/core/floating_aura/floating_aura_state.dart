/// State model for the AURA floating-overlay subsystem.
///
/// Tracks the full lifecycle of the floating overlay:
/// idle → requestingPermission → showing → hiding → idle.
/// Also tracks whether the panel is expanded and the current
/// position of the overlay button.
library;

import 'package:meta/meta.dart' show immutable;

import 'floating_aura_overlay_position.dart';

/// Lifecycle states of the floating overlay.
enum FloatingAuraOverlayStatus {
  /// No overlay is visible, service is idle.
  idle,

  /// Requesting SYSTEM_ALERT_WINDOW permission from the user.
  requestingPermission,

  /// The floating overlay is visible on screen.
  showing,

  /// The overlay is being hidden / torn down.
  hiding,

  /// An error occurred — overlay is not visible.
  error;

  /// Whether the overlay button is currently visible.
  bool get isOverlayVisible => this == FloatingAuraOverlayStatus.showing;

  /// Whether the overlay can be shown from this state.
  bool get canShow =>
      this == FloatingAuraOverlayStatus.idle ||
      this == FloatingAuraOverlayStatus.error;

  /// Whether the overlay can be hidden from this state.
  bool get canHide => this == FloatingAuraOverlayStatus.showing;

  /// Whether the panel can be toggled (expanded/collapsed).
  bool get canTogglePanel => this == FloatingAuraOverlayStatus.showing;
}

/// Immutable snapshot of the floating overlay subsystem state.
@immutable
class FloatingAuraState {
  const FloatingAuraState({
    this.status = FloatingAuraOverlayStatus.idle,
    this.lastError,
    this.hasPermission = false,
    this.isExpanded = false,
    this.position,
  });

  /// Current lifecycle status.
  final FloatingAuraOverlayStatus status;

  /// The most recent error message, if any.
  final String? lastError;

  /// Whether SYSTEM_ALERT_WINDOW permission has been granted.
  final bool hasPermission;

  /// Whether the overlay panel is expanded (vs. collapsed button).
  final bool isExpanded;

  /// Current position of the floating overlay button.
  /// Null means defaults should be used.
  final FloatingAuraOverlayPosition? position;

  /// Whether the overlay is currently visible.
  bool get isOverlayVisible => status.isOverlayVisible;

  /// Whether a new overlay session can be shown.
  bool get canShow => status.canShow;

  /// Whether the visible overlay can be hidden.
  bool get canHide => status.canHide;

  /// Whether the panel can be toggled.
  bool get canTogglePanel => status.canTogglePanel;

  /// Resolved position (falls back to defaults if null).
  FloatingAuraOverlayPosition get resolvedPosition =>
      position ?? FloatingAuraOverlayPosition.defaults;

  /// Copy-with for state transitions.
  FloatingAuraState copyWith({
    FloatingAuraOverlayStatus? status,
    String? lastError,
    bool clearError = false,
    bool? hasPermission,
    bool? isExpanded,
    FloatingAuraOverlayPosition? position,
    bool clearPosition = false,
  }) {
    return FloatingAuraState(
      status: status ?? this.status,
      lastError: clearError ? null : (lastError ?? this.lastError),
      hasPermission: hasPermission ?? this.hasPermission,
      isExpanded: isExpanded ?? this.isExpanded,
      position: clearPosition ? null : (position ?? this.position),
    );
  }

  @override
  String toString() =>
      'FloatingAuraState(status: $status, hasPermission: $hasPermission, '
      'isExpanded: $isExpanded, position: $position, error: $lastError)';
}
