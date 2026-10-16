import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Drives the native TEXO overlay (the pill under the camera).
///
/// Live Mode starts the overlay service while the app is visible (hidden
/// pill), and the pill is only revealed when the user leaves the app and
/// hidden again when the user comes back.
class OverlayController with WidgetsBindingObserver {
  OverlayController({required this.onAction});

  static const MethodChannel _ch = MethodChannel('com.texo.texo/floating_texo_overlay');

  /// Called with: close, mic, mute, subs, translate, guide, tray_open.
  final void Function(String action) onAction;

  bool _active = false;
  bool _visible = false;
  final Map<String, Object?> _last = <String, Object?>{};

  bool get isActive => _active;

  /// Returns false if the "display over other apps" permission is missing.
  Future<bool> start() async {
    if (_active) return true;
    try {
      final Object? has = await _ch.invokeMethod<Object?>('hasPermission');
      final bool granted = has is Map && has['granted'] == true;
      if (!granted) return false;
      _ch.setMethodCallHandler(_onCall);
      WidgetsBinding.instance.addObserver(this);
      await _ch.invokeMethod<Object?>(
        'showOverlay',
        <String, Object?>{'x': 16, 'y': 100, 'hidden': true},
      );
      _active = true;
      _visible = false;
      final AppLifecycleState? s = WidgetsBinding.instance.lifecycleState;
      if (s != null && s != AppLifecycleState.resumed && s != AppLifecycleState.inactive) {
        await _setVisible(true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'overlayAction') {
      onAction('${call.arguments}');
    }
    return null;
  }

  /// Merge [state] (mode, level, emoji, micOff, muted, subs, lang, you, ai).
  void push(Map<String, Object?> state) {
    _last.addAll(state);
    if (_active && _visible) {
      _ch.invokeMethod<Object?>('overlayState', state).catchError((Object _) => null);
    }
  }

  Future<void> _setVisible(bool v) async {
    if (_visible == v) return;
    _visible = v;
    try {
      await _ch.invokeMethod<Object?>('setOverlayVisible', <String, Object?>{'visible': v});
      if (v) {
        await _ch.invokeMethod<Object?>('overlayState', Map<String, Object?>.of(_last));
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_active) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _setVisible(true);
    } else if (state == AppLifecycleState.resumed) {
      _setVisible(false);
    }
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    _visible = false;
    WidgetsBinding.instance.removeObserver(this);
    try {
      await _ch.invokeMethod<Object?>('hideOverlay');
    } catch (_) {}
    _ch.setMethodCallHandler(null);
  }
}
