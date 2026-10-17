import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../presentation/widgets/security_confirmation_host.dart';
import '../ui/texo_ui.dart';
import 'riverpod_backend.dart';

/// Replaces the old MaterialApp: runs the new TEXO UI on top of the existing
/// Riverpod providers.
class TexoUiHost extends StatefulWidget {
  const TexoUiHost({
    super.key,
    required this.navigatorKey,
    required this.initialLang,
    required this.onLangChanged,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String initialLang;
  final ValueChanged<String> onLangChanged;

  @override
  State<TexoUiHost> createState() => _TexoUiHostState();
}

class _TexoUiHostState extends State<TexoUiHost> {
  late final RiverpodBackend _backend;

  @override
  void initState() {
    super.initState();
    _backend = RiverpodBackend(ProviderScope.containerOf(context, listen: false));
  }

  @override
  Widget build(BuildContext context) {
    return TexoUiApp(
      backend: _backend,
      initialLang: widget.initialLang,
      onLangChanged: widget.onLangChanged,
      navigatorKey: widget.navigatorKey,
      homeWrap: (Widget home) => SecurityConfirmationHost(child: home),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: AuraLocale.values.map((AuraLocale l) => l.toLocale()).toList(),
    );
  }
}
