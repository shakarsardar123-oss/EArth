import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'backend.dart';

/// Placeholder "map-like" picture (contours + graticule). It is NOT a real map.
/// In the real app this image comes from the answer (map tile, photo, ...).
ui.Image buildDemoScene() {
  const double s = 328;
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas c = Canvas(rec, const Rect.fromLTWH(0, 0, s, s));
  c.drawRect(
    const Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(s * 0.5, s * 0.45),
        s * 0.75,
        const <Color>[Color(0xFF3D8F6B), Color(0xFF1F6A77), Color(0xFF0B2A52)],
        const <double>[0, 0.5, 1],
      ),
  );
  for (int l = 0; l < 11; l++) {
    final double cx0 = s * (0.42 + 0.1 * math.sin(l * 1.3));
    final double cy0 = s * (0.48 + 0.08 * math.cos(l * 0.9));
    final double base = 26 + l * 17.0;
    final Path p = Path();
    for (int j = 0; j <= 120; j++) {
      final double th = j / 120 * math.pi * 2;
      final double r = base *
          (1 + 0.22 * math.sin(3 * th + l * 0.7) + 0.12 * math.sin(5 * th - l * 1.3) + 0.07 * math.sin(9 * th + l));
      final double x = cx0 + math.cos(th) * r * 1.15;
      final double y = cy0 + math.sin(th) * r * 0.9;
      if (j == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.fromRGBO(255, 255, 255, 0.10 + 0.012 * l),
    );
  }
  final Paint grid = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0x12FFFFFF);
  for (int k = 1; k < 8; k++) {
    c.drawLine(Offset(k * s / 8, 0), Offset(k * s / 8, s), grid);
    c.drawLine(Offset(0, k * s / 8), Offset(s, k * s / 8), grid);
  }
  return rec.endRecording().toImageSync(328, 328);
}

class DemoBackend implements TexoBackend {
  DemoBackend() : _live = LiveVoiceSource();

  final LiveVoiceSource _live;
  ui.Image? _scene;
  Timer? _timer;
  final Stopwatch _sw = Stopwatch();
  double _offset = 0;
  bool _ku = true;

  final ValueNotifier<bool> _cam = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get cameraActive => _cam;

  @override
  Future<void> setCamera(bool on) async {
    _cam.value = on;
  }

  @override
  Future<void> switchCamera() async {}

  @override
  Widget? buildCameraPreview() {
    if (!_cam.value) return null;
    return Container(
      color: const Color(0xFF223355),
      alignment: Alignment.center,
      child: const Icon(Icons.videocam, color: Colors.white54, size: 36),
    );
  }

  final Map<String, bool> _toggles = <String, bool>{'wake': true, 'read': true, 'hap': false};
  bool _hasKey = false;

  @override
  String get userName => 'شاکار';

  @override
  List<UiExtraEntry> get extraEntries => const <UiExtraEntry>[];

  @override
  LiveVoiceSource get liveSource => _live;

  @override
  void beginChat(String? conversationId) {}

  @override
  Future<void> startLive() async {
    _scene ??= buildDemoScene();
    _sw
      ..reset()
      ..start();
    _offset = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (Timer _) => _tick());
  }

  @override
  Future<void> stopLive() async {
    _timer?.cancel();
    _timer = null;
    _sw.stop();
    _live.level.value = 0;
    _live.content.value = null;
  }

  @override
  Future<void> toggleMic() async {
    final double cyc = ((_sw.elapsedMilliseconds / 1000.0) + _offset) % 15;
    final double next = cyc < 6 ? 6 : (cyc < 9 ? 9 : 0);
    _offset += next - cyc;
  }

  void _tick() {
    final double t = (_sw.elapsedMilliseconds / 1000.0) + _offset;
    final double cyc = t % 15;
    final LiveMode mode = cyc < 6
        ? LiveMode.listening
        : (cyc < 9 ? LiveMode.thinking : LiveMode.speaking);
    final double phr = math.pow(math.max(0.0, math.sin(t * 0.85)), 0.7).toDouble();
    final double syl = 0.5 + 0.5 * math.sin(t * 6.3 + math.sin(t * 1.7) * 2);
    final double syl2 = 0.5 + 0.5 * math.sin(t * 3.9 + 1.2);
    double target;
    if (mode == LiveMode.thinking) {
      target = 0.10 + 0.04 * math.sin(t * 2);
    } else if (mode == LiveMode.speaking) {
      target = 0.12 + 0.80 * phr * (0.40 + 0.60 * syl * syl2);
    } else {
      target = 0.08 + 0.85 * phr * (0.30 + 0.70 * syl);
    }
    _live.mode.value = mode;
    _live.level.value = target;
    _live.content.value = (mode == LiveMode.speaking && cyc > 9.8 && cyc < 14.2) ? _scene : null;
    _live.caption.value = mode == LiveMode.thinking
        ? '...'
        : (mode == LiveMode.speaking
            ? (_ku
                ? 'کوردستان ناوچەیەکی جوگرافی و کولتوورییە لە ڕۆژهەڵاتی ناوەڕاست.'
                : 'Kurdistan is a geo-cultural region in the Middle East.')
            : (_ku ? '«کوردستان لە کوێیە؟»' : '\u201cWhere is Kurdistan?\u201d'));
  }

  @override
  Future<UiAttachment?> pickAttachment() async {
    return UiAttachment(name: 'sample.wav', mime: 'audio/wav', bytes: Uint8List(0));
  }

  @override
  Future<String> ask(
    String text, {
    String? conversationId,
    List<UiAttachment> attachments = const <UiAttachment>[],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    return 'بەڵێ، ئێستا دەیکەم. شتێکی تر دەتەوێت؟';
  }

  @override
  Future<void> speak(String text) async {}

  @override
  Future<List<UiConversation>> conversations() async {
    final DateTime now = DateTime.now();
    return <UiConversation>[
      UiConversation(
        id: '1',
        title: 'یوتوب بکەرەوە و گۆرانی بدۆزەوە',
        snippet: 'خەریکی گەڕانم لە یوتوب...',
        time: now.subtract(const Duration(minutes: 20)),
      ),
      UiConversation(
        id: '2',
        title: 'ڕێنمایی چاککردنی ئەپی Flutter',
        snippet: 'لۆگی بێڵدەکە بنێرە',
        time: now.subtract(const Duration(hours: 3)),
      ),
      UiConversation(
        id: '3',
        title: 'کاتژمێری بێدارکەرەوە بۆ بەیانی',
        snippet: 'کاتژمێر ٦:٣٠ دانرا',
        time: now.subtract(const Duration(hours: 4)),
      ),
      UiConversation(
        id: '4',
        title: 'گۆرانی بەرزان جەعفەر',
        snippet: 'داوای لێدانی گۆرانییەکەم نارد',
        time: now.subtract(const Duration(days: 1)),
      ),
      UiConversation(
        id: '5',
        title: 'وەرگێڕانی ڕستەیەک بۆ ئینگلیزی',
        snippet: 'دەقەکەت بنووسە',
        time: now.subtract(const Duration(days: 6)),
      ),
    ];
  }

  @override
  Future<List<UiMessage>> messages(String conversationId) async {
    return const <UiMessage>[
      UiMessage(isUser: false, text: 'سڵاو شاکار! چۆن یارمەتیت بدەم؟'),
      UiMessage(isUser: true, text: 'سڵاو، دەتوانی یوتوب بکەیتەوە؟'),
      UiMessage(isUser: false, text: 'بەڵێ، یوتوبم کردەوە. دەتەوێت گۆرانییەک بدۆزمەوە؟'),
    ];
  }

  @override
  Future<Map<String, bool>> toggles() async => Map<String, bool>.from(_toggles);

  @override
  Future<void> setToggle(String key, bool value) async {
    _toggles[key] = value;
  }

  @override
  Future<Map<String, bool>> permissionStates() async =>
      <String, bool>{'overlay': true, 'access': false};

  @override
  Future<void> openPermission(String key) async {}

  @override
  Future<bool> hasApiKey() async => _hasKey;

  @override
  Future<void> setApiKey(String key) async {
    _hasKey = key.trim().isNotEmpty;
  }
}
