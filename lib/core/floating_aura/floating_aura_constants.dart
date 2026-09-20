/// Platform-channel names and method constants for the AURA
/// floating-overlay subsystem.
///
/// These are shared between the Dart [FloatingAuraMethodChannel]
/// and the Kotlin [OverlayPlugin]. Changing any value here
/// requires the same change on the native side.
library;

/// MethodChannel for floating overlay control operations.
const String floatingAuraMethodChannelName =
    'com.aura.aura_assistant/floating_aura_overlay';

/// Method names invoked on the platform side.
abstract final class FloatingAuraMethodNames {
  static const String requestPermission = 'requestPermission';
  static const String openOverlaySettings = 'openOverlaySettings';
  static const String hasPermission = 'hasPermission';
  static const String showOverlay = 'showOverlay';
  static const String hideOverlay = 'hideOverlay';
  static const String updatePosition = 'updatePosition';
  static const String togglePanel = 'togglePanel';
  static const String isOverlayVisible = 'isOverlayVisible';
  static const String isSupported = 'isSupported';
}

/// Event names sent from native to Dart (MethodChannel callbacks).
abstract final class FloatingAuraEventNames {
  static const String onOverlayPositionChanged =
      'onOverlayPositionChanged';
  static const String onOverlayPanelToggled = 'onOverlayPanelToggled';
  static const String onOverlayVisibilityChanged =
      'onOverlayVisibilityChanged';
}

/// Default overlay position offsets (dp from top-left of screen).
abstract final class FloatingAuraDefaults {
  /// Default X position (dp from left edge).
  static const double defaultPositionX = 16.0;

  /// Default Y position (dp from top edge, status-bar offset).
  static const double defaultPositionY = 100.0;

  /// Collapsed button size (dp).
  static const double collapsedSize = 56.0;

  /// Expanded panel width (dp).
  static const double expandedWidth = 280.0;

  /// Expanded panel height (dp).
  static const double expandedHeight = 400.0;
}
