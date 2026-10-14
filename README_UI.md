# TEXO UI package (lib/ui)

Self-contained Flutter UI: Home, Live (water orb, rings, comets), Chat, History,
Settings, drawer, Kurdish (RTL) / English (LTR) switching.

* `lib/ui/texo_ui.dart` - public API: `TexoUiApp`, `TexoBackend`, `LiveVoiceSource`.
* `lib/ui/preview_main.dart` - runs the UI with `DemoBackend` (fake voice, demo answer image).
* The app connects by implementing `TexoBackend` (chat, live state/levels, history, settings).
* Logo asset: `assets/logo/texo_logo.png` (add it to pubspec.yaml `flutter: assets:`).
