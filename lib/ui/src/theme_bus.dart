import 'package:flutter/foundation.dart';

/// Lets code outside the UI tree (voice and chat commands) ask for a theme
/// change. Values: 'dark', 'light', 'system'. The UI resets it to ''.
final ValueNotifier<String> themeRequest = ValueNotifier<String>('');
