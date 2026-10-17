import 'package:flutter/material.dart';

import 'backend.dart';
import 'colors.dart';
import 'home_screen.dart';
import 'scope.dart';

/// The whole TEXO UI. Put it where the old MaterialApp was and pass a
/// [TexoBackend] that connects it to the app logic.
class TexoUiApp extends StatefulWidget {
  const TexoUiApp({
    super.key,
    required this.backend,
    this.initialLang = 'ku',
    this.onLangChanged,
    this.navigatorKey,
    this.wrap,
    this.homeWrap,
    this.localizationsDelegates,
    this.supportedLocales,
  });

  final TexoBackend backend;
  final String initialLang;

  /// Called with 'ku' or 'en' when the user switches language in Settings.
  final ValueChanged<String>? onLangChanged;

  /// For notification taps that navigate (alarms).
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Wrap the whole UI (overlay hosts, confirmation dialogs, ...).
  final Widget Function(BuildContext context, Widget child)? wrap;

  /// Wraps the home route (must live INSIDE the navigator, e.g. dialog hosts).
  final Widget Function(Widget home)? homeWrap;

  /// Needed by screens that still use generated localisations.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Iterable<Locale>? supportedLocales;

  @override
  State<TexoUiApp> createState() => _TexoUiAppState();
}

class _TexoUiAppState extends State<TexoUiApp> {
  late final UiSettings _settings = UiSettings(lang: widget.initialLang);
  late String _lastLang = widget.initialLang;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettings);
  }

  void _onSettings() {
    if (_settings.lang != _lastLang) {
      _lastLang = _settings.lang;
      widget.onLangChanged?.call(_lastLang);
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
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
          final bool localized = widget.localizationsDelegates != null;
          return MaterialApp(
            navigatorKey: widget.navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'TEXO',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: UiColors.violet,
              scaffoldBackgroundColor: UiColors.lightTop,
            ),
            locale: localized ? Locale(_settings.lang) : null,
            localizationsDelegates: widget.localizationsDelegates,
            supportedLocales: widget.supportedLocales ?? const <Locale>[Locale('en', 'US')],
            builder: (BuildContext context, Widget? child) {
              final Widget inner = Directionality(
                textDirection: dir,
                child: child ?? const SizedBox.shrink(),
              );
              final Widget Function(BuildContext, Widget)? wrap = widget.wrap;
              return wrap == null ? inner : wrap(context, inner);
            },
            home: widget.homeWrap == null ? const HomeScreen() : widget.homeWrap!(const HomeScreen()),
          );
        },
      ),
    );
  }
}
