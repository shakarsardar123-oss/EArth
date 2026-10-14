import 'package:flutter/material.dart';

import 'texo_ui.dart';

/// Preview entry: the new UI with demo data (no app logic).
///   flutter run -t lib/ui/preview_main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TexoUiApp(backend: DemoBackend()));
}
