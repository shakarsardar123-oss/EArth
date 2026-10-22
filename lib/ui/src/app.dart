import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backend.dart';
import 'colors.dart';
import 'dark.dart';
import 'home_screen.dart';
import 'scope.dart';

/// Flutter ships Material strings for many languages but not for Kurdish. When
/// the app locale is Kurdish this delegate hands out the English Material
/// strings instead, so Material widgets (text fields, drawer, dialogs, ...)
/// keep working. It is listed AFTER the real delegates, so it is only used
/// when they do not support the locale.
class _MaterialFallbackDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialFallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) => false;
}

class _CupertinoFallbackDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoFallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) => false;
}

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
          final List<LocalizationsDelegate<dynamic>>? delegates = localized
              ? <LocalizationsDelegate<dynamic>>[
                  ...widget.localizationsDelegates!,
                  const _MaterialFallbackDelegate(),
                  const _CupertinoFallbackDelegate(),
                ]
              : null;
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
            localizationsDelegates: delegates,
            supportedLocales: widget.supportedLocales ?? const <Locale>[Locale('en', 'US')],
            builder: (BuildContext context, Widget? child) {
              final Widget inner = Directionality(
                textDirection: dir,
                child: child ?? const SizedBox.shrink(),
              );
              final Widget Function(BuildContext, Widget)? wrap = widget.wrap;
              final Widget wrapped = wrap == null ? inner : wrap(context, inner);
              final String mode = _settings.theme;
              final bool dark = mode == 'dark' ||
                  (mode == 'system' &&
                      MediaQuery.platformBrightnessOf(context) == Brightness.dark);
              if (!dark) return UiDarkScope(dark: false, child: wrapped);
              return UiDarkScope(
                dark: true,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(kUiDarkMatrix),
                    child: wrapped,
                  ),
                ),
              );
            },
            home: widget.homeWrap == null ? const HomeScreen() : widget.homeWrap!(const HomeScreen()),
          );
        },
      ),
    );
  }
}
