import 'package:flutter/material.dart';

import 'backend.dart';
import 'strings.dart';

class UiSettings extends ChangeNotifier {
  UiSettings({String lang = 'ku'}) : _lang = lang;

  String _lang;
  String _theme = 'light';

  String get lang => _lang;
  String get theme => _theme;

  void setLang(String value) {
    if (value == _lang) return;
    _lang = value;
    notifyListeners();
  }

  void setTheme(String value) {
    if (value == _theme) return;
    _theme = value;
    notifyListeners();
  }
}

class UiScope extends InheritedNotifier<UiSettings> {
  const UiScope({
    Key? key,
    required UiSettings settings,
    required this.backend,
    required Widget child,
  }) : super(key: key, notifier: settings, child: child);

  final TexoBackend backend;

  static UiScope of(BuildContext context) {
    final UiScope? scope = context.dependOnInheritedWidgetOfExactType<UiScope>();
    assert(scope != null, 'UiScope not found above this context');
    return scope!;
  }

  UiSettings get settings => notifier!;

  UiStrings get s => UiStrings(settings.lang);
}
