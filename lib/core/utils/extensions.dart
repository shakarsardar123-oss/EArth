import 'package:flutter/material.dart';

/// Shared extension methods used across the app.
extension ContextExtensions on BuildContext {
  /// Shortcut for [Theme.of(this)].
  ThemeData get theme => Theme.of(this);

  /// Shortcut for [MediaQuery.of(this)].
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Shortcut for [MediaQuery.of(this).size].
  Size get screenSize => mediaQuery.size;

  /// Shortcut for [ScaffoldMessenger.of(this)].
  ScaffoldMessengerState get scaffoldMessenger => ScaffoldMessenger.of(this);
}

extension StringExtensions on String {
  /// Capitalizes the first letter of the string.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Returns `true` if this string is a non-empty value after trimming.
  bool get isNotBlank => trim().isNotEmpty;
}
