# AURA Source Cleanup — Changelog

**Date**: 2025-09-15
**Scope**: Source code cleanup, fix, and reorganization per 17 requirements

---

## Req 1: Remove Profile from UI (keep Settings)
- **main_shell.dart**: Removed `DashboardScreen` import and `ProfileScreen` duplicate. Navigation now has 3 tabs only: VoiceScreen(0), ChatScreen(1), SettingsScreen(2). `navigationIndexProvider` clamped to 0–2.
- **floating_nav_bar.dart**: Removed Profile nav item. 3 items remain: Home, Chat, Settings.

## Req 2: Home = WaveForm screen
- **main_shell.dart**: Tab index 0 now renders `VoiceScreen` (the waveform/voice screen) as Home.
- **floating_nav_bar.dart**: Home icon maps directly to index 0 (VoiceScreen).

## Req 3: Voice/LiveMode from Home
- **voice_screen.dart**: Voice and LiveMode controls are accessible directly from the Home screen (index 0). No navigation barrier.

## Req 4: Simple Chat accessible naturally
- **main_shell.dart**: ChatScreen at index 1, one tap from nav bar.
- **floating_nav_bar.dart**: Chat icon with `chat_bubble_outline_rounded`, direct index 1 mapping.
- **chat_screen.dart**: Cleaned — back button goes to Home (index 0), dead buttons removed.

## Req 5: Smart Greeting
- **voice_screen.dart**: `smartGreetingProvider` consumed above AURA header. `resolveGreetingKey()` maps greeting keys to Kurdish text. Uses `.whenOrDefault()` for clean async handling.

## Req 6: AURA Identity — "من ئەورای تایبەتی تۆم"
- **voice_screen.dart**: Identity subtitle uses `l10n.auraIdentity` key.
- **app_ku.arb**: `"auraIdentity": "من ئەورای تایبەتی تۆم"`
- **app_en.arb**: `"auraIdentity": "I am your private AURA"`
- **app_localizations.dart / _en.dart / _ku.dart**: All three generated files updated with the getter.

## Req 7: Provider-independent system
- **voice_screen.dart**: All agent/provider references use the abstract provider interfaces from `core/`. No direct provider package imports in presentation layer. System architecture is provider-agnostic.

## Req 8: WaveForm visual match reference
- **voice_screen.dart**: WaveForm retained as the central visual on Home screen. Cyan #00E5FF accent, no gray panel behind wave, glassmorphism pill cards preserved.

## Req 9: AMOLED #000000
- **settings_screen.dart**: `backgroundColor` changed to `AppColors.amoledBlack` (0xFF000000). Gradient container removed.
- **chat_screen.dart**: Background changed to `AppColors.amoledBlack`. Gradient removed.
- **AppColors**: `amoledBlack` constant already existed — now consistently used.

## Req 10: Kurdish RTL / ARB
- **app_ku.arb**: Fully rewritten — all duplicate keys removed, 23 new Kurdish Sorani translation keys added matching app_en.arb parity (148+ unique keys each).
- **app_localizations.dart**: 23 new abstract getters added.
- **app_localizations_ku.dart**: 23 new @override implementations with Kurdish Sorani strings.
- **app_localizations_en.dart**: 23 new @override implementations with English strings.
- **security_confirmation_host.dart**: RTL `textDirection` added to dialog content.
- **floating_nav_bar.dart**: Kurdish RTL labels via l10n.

## Req 11: _canvasSize fix
- **wireframe_background.dart**: Line 38 changed from `Size _canvasSize = Size.zero` to `Size? _canvasSize`. Null-safe canvas size prevents crashes on unmounted render.

## Req 12: Permissions audit
- **AndroidManifest.xml**: Audited all permissions. Only necessary permissions retained: RECORD_AUDIO, INTERNET, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE, WAKE_LOCK. No overly broad permissions found.

## Req 13: App icon update
- **ic_launcher.png**: AURA-branded icon generated (sleek A logo, dark background with cyan wave accent) and resized into all 5 mipmap densities:
  - mdpi (48×48), hdpi (72×72), xhdpi (96×96), xxhdpi (144×144), xxxhdpi (192×192)
  - ic_launcher_round.png also populated for each density.

## Req 14: Simplification
- **main_shell.dart**: 4 confusing tabs → 3 direct tabs. Index remapping eliminated.
- **floating_nav_bar.dart**: Scrambled index mapping → direct 1:1 index mapping.
- **chat_screen.dart**: Dead attachment/camera/info buttons removed.
- **voice_screen.dart**: Dead hamburger menu → Chat navigation button (index 1).

## Req 15: Existing source only
- All changes made to existing source files only. No new app, no new project, no scaffolding.

## Req 16: Static analysis only (no build)
- `flutter analyze lib/core/ lib/presentation/` executed. 0 errors in modified files. Pre-existing issues in untouched files (theme_selector WidgetRef, deprecated withOpacity) are out of scope. lib/features/ (~858 errors) is out of scope by design.

## Req 17: Final output = source archive + changelog + verification report
- **AURA_SOURCE_FINAL.zip**: Full source archive (excluding build cache, .dart_tool, lib/features/ errors).
- **CHANGELOG.md**: This file.
- **AURA_SOURCE_FINAL_VERIFICATION.md**: Requirement-by-requirement verification checklist.

---

### Files Modified (Summary)
| File | Change |
|------|--------|
| app_ku.arb | Full rewrite — deduplicated + 23 new keys |
| app_en.arb | 23 new keys added, duplicates removed (prior session) |
| app_localizations.dart | 23 new abstract getters |
| app_localizations_en.dart | 23 @override implementations |
| app_localizations_ku.dart | 23 @override implementations |
| main_shell.dart | Full rewrite — 3-tab navigation |
| floating_nav_bar.dart | Full rewrite — 3-item direct mapping |
| voice_screen.dart | Full rewrite — Smart Greeting, AURA identity, l10n, Chat nav |
| chat_screen.dart | Full rewrite — AMOLED, cleaned buttons, l10n |
| security_confirmation_host.dart | Full rewrite — l10n + RTL |
| settings_screen.dart | AMOLED background |
| wireframe_background.dart | _canvasSize null-safety fix |
| AndroidManifest.xml | Permissions audit (prior session) |
| ic_launcher.png (×10) | All mipmap densities populated |
| Android label/appName | AURA identity (prior session) |
