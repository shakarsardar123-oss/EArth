// AURA Reusable Component Library — barrel export
// Only exports active, new-design-system widgets.

// ─── New Design System (Glassmorphism + Orb) ───
export 'glass_card.dart';
export 'glass_dialog.dart';       // GlassDialog, GlassTextField, GlassButton
export 'aura_orb.dart';
export 'aura_wave_form.dart';
export 'holographic_globe.dart';
export 'floating_nav_bar.dart';
export 'wireframe_background.dart';

// ─── Active Feature Widgets ───
export 'aura_reaction_banner.dart';  // Used by: dashboard, chat, voice
export 'camera_preview_widget.dart'; // Used by: wake_alarm_screen (camera feed)
export 'vision_overlay.dart';       // Used by: vision_screen
export 'permissions_section.dart'; // Used by: settings_screen
export 'api_key_settings_section.dart'; // Used by: settings_screen
export 'name_editor.dart';      // Used by: settings_screen
export 'theme_selector.dart';   // Used by: settings_screen
export 'reaction_banner_animations.dart';
export 'reaction_renderers/reaction_renderers.dart';