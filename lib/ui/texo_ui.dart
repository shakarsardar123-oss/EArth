/// The new TEXO UI (screens, Live visual, i18n). Self-contained: it only needs
/// a [TexoBackend] from the app. See README_UI.md.
library;

export 'src/app.dart' show TexoUiApp;
export 'src/backend.dart';
export 'src/demo_backend.dart' show DemoBackend, buildDemoScene;
export 'src/scope.dart' show UiScope, UiSettings;
