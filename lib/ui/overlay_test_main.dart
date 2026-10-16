import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Overlay diagnostics app: talks to the SAME native overlay bridge as TEXO
/// and prints exactly what happens (permission, foreground service, addView,
/// button presses on the overlay).
///   flutter build apk -t lib/ui/overlay_test_main.dart
const MethodChannel _ch = MethodChannel('com.texo.texo/floating_texo_overlay');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _OverlayTestPage(),
  ));
}

class _OverlayTestPage extends StatefulWidget {
  const _OverlayTestPage();

  @override
  State<_OverlayTestPage> createState() => _OverlayTestPageState();
}

class _OverlayTestPageState extends State<_OverlayTestPage> {
  final List<String> _lines = <String>[];
  Timer? _demo;
  final Stopwatch _sw = Stopwatch();
  bool _micOff = false;
  bool _muted = false;
  bool _subs = false;

  @override
  void initState() {
    super.initState();
    _add('Android: ${Platform.operatingSystemVersion}');
    _ch.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'overlayAction') {
        final String a = '${call.arguments}';
        _add('overlayAction: $a');
        if (a == 'mic') _micOff = !_micOff;
        if (a == 'mute') _muted = !_muted;
        if (a == 'subs') _subs = !_subs;
        if (a == 'close') _stopDemo();
      }
      return null;
    });
  }

  @override
  void dispose() {
    _demo?.cancel();
    super.dispose();
  }

  void _add(String s) {
    final String t = DateTime.now().toIso8601String().substring(11, 19);
    if (!mounted) return;
    setState(() => _lines.add('[$t] $s'));
  }

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      final Object? r = await _ch.invokeMethod<Object?>(method, args);
      _add('$method -> $r');
    } on PlatformException catch (e) {
      _add('$method ERROR ${e.code}: ${e.message}');
    } catch (e) {
      _add('$method EXCEPTION $e');
    }
  }

  Future<void> _perm(String name, Permission p) async {
    try {
      final PermissionStatus before = await p.status;
      final PermissionStatus after = await p.request();
      _add('$name: $before -> $after');
    } catch (e) {
      _add('$name EXCEPTION $e');
    }
  }

  void _stopDemo() {
    _demo?.cancel();
    _demo = null;
  }

  void _toggleDemo() {
    if (_demo != null) {
      _stopDemo();
      _add('demo voice stopped');
      return;
    }
    _sw
      ..reset()
      ..start();
    _add('demo voice started (mode/level/emoji every 120 ms)');
    _demo = Timer.periodic(const Duration(milliseconds: 120), (Timer _) {
      final double t = _sw.elapsedMilliseconds / 1000.0;
      final double c = t % 12;
      final String mode = c < 4 ? 'listening' : (c < 6.5 ? 'thinking' : 'speaking');
      final double phr = math.pow(math.max(0.0, math.sin(t * 0.85)), 0.7).toDouble();
      final double syl = 0.5 + 0.5 * math.sin(t * 6.3 + math.sin(t * 1.7) * 2);
      double level;
      String emoji;
      if (mode == 'thinking') {
        level = 0.15;
        emoji = '\u{1F914}';
      } else if (mode == 'speaking') {
        level = 0.15 + 0.8 * phr * (0.4 + 0.6 * syl);
        const List<String> e = <String>['\u{1F604}', '\u{1F62E}', '\u{1F3B5}', '\u{1F970}'];
        emoji = e[(t / 2.2).floor() % e.length];
      } else {
        level = 0.1 + 0.85 * phr * (0.3 + 0.7 * syl);
        emoji = '\u{1F642}';
      }
      _ch.invokeMethod<Object?>('overlayState', <String, Object?>{
        'mode': mode,
        'level': level,
        'emoji': emoji,
        'micOff': _micOff,
        'muted': _muted,
        'lang': 'ku',
      });
    });
  }

  Widget _b(String label, VoidCallback onTap) =>
      ElevatedButton(onPressed: onTap, child: Text(label));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEXO overlay test')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _b('1 Mic permission', () => _perm('microphone', Permission.microphone)),
                  _b('2 Notification permission', () => _perm('notification', Permission.notification)),
                  _b('3 hasPermission', () => _call('hasPermission')),
                  _b('4 Open overlay settings', () => _call('openOverlaySettings')),
                  _b('5 SHOW overlay now', () => _call('showOverlay', <String, Object?>{'x': 16, 'y': 100})),
                  _b('6 isOverlayVisible', () => _call('isOverlayVisible')),
                  _b('7 HIDE overlay', () => _call('hideOverlay')),
                  _b('8 Show in 10 s (press Home now)', () {
                    _add('scheduled: showOverlay in 10 s');
                    Timer(const Duration(seconds: 10), () {
                      _call('showOverlay', <String, Object?>{'x': 16, 'y': 100});
                    });
                  }),
                  _b('9 Demo voice ON/OFF', _toggleDemo),
                  _b('10 Subtitle texts', () {
                    _call('overlayState', <String, Object?>{
                      'subs': true,
                      'you': '«چۆن ستۆرەج بدۆزمەوە؟»',
                      'ai': 'سەرەتا ڕێکخستنەکان بکەرەوە، پاشان بەرەو خوار سکڕۆڵ بکە تا «ستۆرەج» ببینیت.',
                    });
                  }),
                  _b('Copy log', () {
                    Clipboard.setData(ClipboardData(text: _lines.join('\n')));
                    _add('log copied');
                  }),
                  _b('Clear', () => setState(_lines.clear)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _lines.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
