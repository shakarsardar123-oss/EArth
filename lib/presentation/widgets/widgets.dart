// AURA Reusable Component Library — barrel export
// Only exports active, new-design-system widgets.

// ─── New Design System (Glassmorphism + Orb) ───
export 'glass_card.dart';
export 'glass_dialog.dart';       // GlassDialog, GlassTextField, GlassButton
export 'wireframe_background.dart';

// ─── Active Feature Widgets ───
// Used by: dashboard, chat, voice
export 'camera_preview_widget.dart'; // Used by: wake_alarm_screen (camera feed)
export 'vision_overlay.dart';       // Used by: vision_screen
export 'permissions_section.dart'; // Used by: settings_screen
export 'api_key_settings_section.dart'; // Used by: settings_screen
export 'name_editor.dart';      // Used by: settings_screen
export 'theme_selector.dart';   // Used by: settings_screen
