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

  /// Called with: close, hide, show, tray_open, tray_close and name=1 / name=0
  /// for the toggles (mic, mute, subs, translate, guide).
  final void Function(String action) onAction;

  bool _active = false;

  /// True while a wake-word session runs: show the pill even if the app is open.
  bool forceVisible = false;
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
      if (forceVisible ||
          (s != null && s != AppLifecycleState.resumed && s != AppLifecycleState.inactive)) {
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

  /// Another part of the app may register its own handler on the same native
  /// channel (only the last one gets the overlay's button events). Call this
  /// to take it back.
  void rebind() {
    if (_active) _ch.setMethodCallHandler(_onCall);
  }

  /// Puts the pill in the right state for the current app state (visible only
  /// while the app is in the background).
  Future<void> syncVisibility() async {
    if (!_active) return;
    final AppLifecycleState? s = WidgetsBinding.instance.lifecycleState;
    final bool want = forceVisible ||
        (s != null && s != AppLifecycleState.resumed && s != AppLifecycleState.inactive);
    _visible = !want; // force the native call
    await _setVisible(want);
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
      _ch.setMethodCallHandler(_onCall);
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
      _setVisible(forceVisible);
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
