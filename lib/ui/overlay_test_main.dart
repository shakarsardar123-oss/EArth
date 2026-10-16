import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Overlay diagnostics app: talks to the SAME native overlay bridge as TEXO
/// and prints exactly what happens (permission, foreground service, addView).
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

  @override
  void initState() {
    super.initState();
    _add('Android: ${Platform.operatingSystemVersion}');
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
