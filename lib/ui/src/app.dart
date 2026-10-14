import 'package:flutter/material.dart';

import 'backend.dart';
import 'colors.dart';
import 'home_screen.dart';
import 'scope.dart';

/// The whole TEXO UI. Put it where the old MaterialApp was and pass a
/// [TexoBackend] that connects it to the app logic.
class TexoUiApp extends StatefulWidget {
  const TexoUiApp({super.key, required this.backend, this.initialLang = 'ku'});

  final TexoBackend backend;
  final String initialLang;

  @override
  State<TexoUiApp> createState() => _TexoUiAppState();
}

class _TexoUiAppState extends State<TexoUiApp> {
  late final UiSettings _settings = UiSettings(lang: widget.initialLang);

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiScope(
      settings: _settings,
      backend: widget.backend,
      child: AnimatedBuilder(
        animation: _settings,
        builder: (BuildContext context, Widget? _) {
          final TextDirection dir =
              _settings.lang == 'ku' ? TextDirection.rtl : TextDirection.ltr;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'TEXO',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: UiColors.violet,
              scaffoldBackgroundColor: UiColors.lightTop,
            ),
            builder: (BuildContext context, Widget? child) => Directionality(
              textDirection: dir,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
