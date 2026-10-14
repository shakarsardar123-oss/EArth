import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'backend.dart';
import 'colors.dart';

class _Ripple {
  _Ripple(this.t);

  final double t;
}

class _Bubble {
  _Bubble(this.x, this.y, this.s, this.v, this.ph);

  double x;
  double y;
  final double s;
  final double v;
  final double ph;
}

class _Comet {
  _Comet(this.kind, this.born, this.life, this.hb, this.h4);

  /// 0 = orbit (thinking), 1 = streak (top to bottom), 2 = radial (in/out).
  final int kind;
  final double born;
  final double life;
  final double hb;
  final int h4;
  final List<Offset> pts = <Offset>[];
  double a0 = 0;
  double w = 0;
  double r = 0;
  double x0 = 0;
  double y0 = 0;
  double x1 = 0;
  double y1 = 0;
  double xc = 0;
  double yc = 0;
  double sw = 0;
  double rIn = 0;
  double rOut = 0;
  double dir = 1;
}

/// Paints the whole Live screen visual. Give it a [repaint] listenable that
/// fires every frame (an AnimationController that repeats).
class LivePainter extends CustomPainter {
  LivePainter(this.src, {Listenable? repaint}) : super(repaint: repaint) {
    for (int i = 0; i < 12; i++) {
      _bub.add(_Bubble(
        _rnd.nextDouble() * 1.4 - 0.7,
        _rnd.nextDouble(),
        0.7 + _rnd.nextDouble() * 1.6,
        0.05 + _rnd.nextDouble() * 0.08,
        _rnd.nextDouble() * 6,
      ));
    }
  }

  final LiveVoiceSource src;

  final math.Random _rnd = math.Random();
  final Stopwatch _sw = Stopwatch()..start();
  final List<_Ripple> _ripples = <_Ripple>[];
  final List<_Ripple> _inRip = <_Ripple>[];
  final List<_Comet> _comets = <_Comet>[];
  final List<_Bubble> _bub = <_Bubble>[];

  double _last = 0;
  double _lv = 0;
  double _lv2 = 0;
  double _show = 0;
  double _acc = 0;
  double _lastRip = -9;
  double _lastIn = -9;

  static const int _rayCount = 42;

  void _spawn(LiveMode mode, double t, double r0, Size size, double k) {
    final double hb = _rnd.nextDouble() * 360;
    final int h4 = _rnd.nextInt(4);
    if (mode == LiveMode.thinking) {
      final _Comet c = _Comet(0, t, 3.4 + _rnd.nextDouble(), hb, h4);
      c.r = r0 + (40 + _rnd.nextDouble() * 70) * k;
      c.a0 = _rnd.nextDouble() * math.pi * 2;
      c.w = (_rnd.nextBool() ? -1.0 : 1.0) * (0.5 + _rnd.nextDouble() * 0.4);
      _comets.add(c);
    } else if (_rnd.nextDouble() < 0.8) {
      final _Comet c = _Comet(1, t, 5.0 + _rnd.nextDouble() * 1.2, hb, h4);
      final double x0 = 30 * k + _rnd.nextDouble() * (size.width - 60 * k);
      final double x1 = x0 + (_rnd.nextDouble() - 0.5) * 100 * k;
      c.x0 = x0;
      c.x1 = x1;
      c.y0 = -20;
      c.y1 = size.height + 20;
      c.xc = (x0 + x1) / 2 + (_rnd.nextDouble() - 0.5) * 140 * k;
      c.yc = size.height * (0.35 + _rnd.nextDouble() * 0.3);
      _comets.add(c);
    } else {
      final _Comet c = _Comet(2, t, 6.0 + _rnd.nextDouble() * 1.5, hb, h4);
      c.a0 = -math.pi / 2 + (_rnd.nextInt(_rayCount) * math.pi * 2) / _rayCount;
      c.dir = mode == LiveMode.speaking ? 1.0 : -1.0;
      c.sw = (_rnd.nextBool() ? -1.0 : 1.0) * (0.2 + _rnd.nextDouble() * 0.4);
      c.rIn = r0 + 24 * k;
      c.rOut = (300 + _rnd.nextDouble() * 200) * k;
      _comets.add(c);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = _sw.elapsedMicroseconds / 1e6;
    final double dt = _last == 0 ? 0.016 : math.min(0.05, t - _last);
    _last = t;

    final LiveMode mode = src.mode.value;
    final bool speaking = mode == LiveMode.speaking;
    final bool thinking = mode == LiveMode.thinking;
    final double target = src.level.value.clamp(0.0, 1.0).toDouble();
    _lv += (target - _lv) * (1 - math.exp(-dt * (target > _lv ? 18 : 8)));
    _lv2 += (_lv - _lv2) * (1 - math.exp(-dt * (_lv > _lv2 ? 6.5 : 3)));
    final double lv = _lv;
    final double lv2 = _lv2;

    final double k = size.width / 390.0;
    final double cx = size.width / 2;
    final double cy = size.height * 0.456;
    final double r0 = 82.0 * k;
    final Offset center = Offset(cx, cy);
    final Rect full = Offset.zero & size;

    // ---- aurora backdrop ---------------------------------------------------
    final List<List<int>> pal = speaking
        ? const <List<int>>[
            <int>[255, 190, 90],
            <int>[255, 110, 170],
            <int>[140, 120, 255],
          ]
        : thinking
            ? const <List<int>>[
                <int>[150, 120, 255],
                <int>[90, 200, 255],
                <int>[255, 130, 220],
              ]
            : const <List<int>>[
                <int>[60, 200, 255],
                <int>[160, 100, 255],
                <int>[255, 90, 170],
              ];
    for (int i = 0; i < 3; i++) {
      final double a = t * 0.35 + i * 2.1;
      final Offset b = Offset(cx + math.cos(a) * 70 * k, cy + math.sin(a * 1.3) * 50 * k);
      final List<int> col = pal[i];
      final Paint p = Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          b,
          (150 + 70 * lv) * k,
          <Color>[
            UiColors.rgba(col[0], col[1], col[2], 0.16 + 0.22 * lv),
            UiColors.rgba(col[0], col[1], col[2], 0.0),
          ],
        );
      canvas.drawRect(full, p);
    }

    // ---- outer ripples -----------------------------------------------------
    if (!thinking && lv > 0.42 && t - _lastRip > 0.55) {
      _ripples.add(_Ripple(t));
      _lastRip = t;
    }
    _ripples.removeWhere((_Ripple r) => t - r.t >= 1.8);
    for (final _Ripple r in _ripples) {
      final double p = (t - r.t) / 1.8;
      final double a = (1 - p) * 0.22;
      final Paint rp = Paint()
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.plus
        ..strokeWidth = (2.4 * (1 - p) + 0.4) * k
        ..color = speaking
            ? UiColors.rgba(255, 214, 140, a)
            : UiColors.rgba(150, 200, 255, a);
      canvas.drawCircle(center, r0 + (12 + p * 150) * k, rp);
    }

    // ---- wobbling rings ----------------------------------------------------
    void ring(double rBase, double amp, double phase, Color col, Color glow, double lw, double sp) {
      for (int pass = 0; pass < 2; pass++) {
        final Path path = Path();
        for (int j = 0; j <= 200; j++) {
          final double th = j / 200 * math.pi * 2;
          final double w = math.sin(th * 3 + t * 1.5 * sp + phase) * 0.55 +
              math.sin(th * 5 - t * 2.1 * sp + phase * 1.7) * 0.30 +
              math.sin(th * 2 + t * 0.9 * sp - phase) * 0.35;
          final double rr = rBase + w * amp;
          final double x = cx + math.cos(th) * rr;
          final double y = cy + math.sin(th) * rr;
          if (j == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..blendMode = BlendMode.plus
            ..strokeWidth = (pass == 0 ? lw * 4.5 : lw) * k
            ..color = pass == 0 ? glow : col,
        );
      }
    }

    ring(r0 + 24 * k, (8 + 34 * lv2) * k, 0,
        UiColors.rgba(200, 240, 255, 0.35 + 0.4 * lv2), UiColors.rgba(120, 200, 255, 0.07), 1.8, 1.0);
    ring(
        r0 + 46 * k,
        (10 + 40 * lv2) * k,
        2.1,
        speaking ? UiColors.rgba(255, 205, 130, 0.5) : UiColors.rgba(255, 140, 230, 0.45),
        UiColors.rgba(255, 150, 200, 0.06),
        1.6,
        0.8);
    ring(r0 + 66 * k, (10 + 34 * lv2) * k, 4.2, UiColors.rgba(160, 140, 255, 0.38),
        UiColors.rgba(140, 120, 255, 0.05), 1.4, 0.6);

    // ---- orb ---------------------------------------------------------------
    final double rr = r0 * (1 + 0.025 * lv + (thinking ? 0.02 * math.sin(t * 3) : 0));

    canvas.drawCircle(
      center,
      rr * 2.0,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          center,
          rr * 2.0,
          <Color>[
            speaking
                ? UiColors.rgba(255, 170, 90, 0.5 + 0.2 * lv)
                : UiColors.rgba(110, 70, 240, 0.55 + 0.2 * lv),
            UiColors.rgba(110, 70, 240, 0.0),
          ],
          const <double>[0.45, 1.0],
        ),
    );

    canvas.drawCircle(
      center,
      rr,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          rr,
          const <Color>[
            Color(0xFFDDF9FF),
            Color(0xFF86E3FF),
            Color(0xFF2FA0EE),
            Color(0xFF1D56BE),
            Color(0xFF112A78),
            Color(0xFF080F3A),
          ],
          const <double>[0, 0.10, 0.34, 0.62, 0.86, 1.0],
          TileMode.clamp,
          null,
          Offset(cx - rr * 0.2, cy - rr * 0.28),
          0,
        ),
    );

    // water + answer image, clipped to the sphere
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: rr - 1)));

    final ui.Image? img = src.content.value;
    final double showT = (speaking && img != null) ? 1.0 : 0.0;
    _show += (showT - _show) * (1 - math.exp(-dt * 3.6));
    final double wf = 1 - 0.55 * _show;

    for (int i = 0; i < 6; i++) {
      final double a = t * (0.35 + i * 0.07) + i * 1.7;
      final Offset b = Offset(
        cx + math.cos(a * 1.1) * rr * 0.5,
        cy + math.sin(a * 0.9 + i) * rr * 0.5,
      );
      final double rad = rr * (0.28 + 0.1 * math.sin(t + i));
      canvas.drawCircle(
        b,
        rad,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            b,
            rad,
            <Color>[
              UiColors.rgba(190, 245, 255, (0.10 + 0.10 * lv2) * wf),
              UiColors.rgba(190, 245, 255, 0.0),
            ],
          ),
      );
    }

    final Paint waveP = Paint()
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.plus
      ..strokeWidth = 1.2 * k
      ..color = UiColors.rgba(200, 245, 255, (0.10 + 0.08 * lv2) * wf);
    for (int l = 0; l < 4; l++) {
      final Path wp = Path();
      bool first = true;
      for (double x = -rr; x <= rr; x += 6 * k) {
        final double y = cy -
            rr * 0.6 +
            l * rr * 0.4 +
            math.sin(x / k * 0.05 + t * (1.0 + l * 0.3) + l) * (4 + 8 * lv2) * k;
        if (first) {
          wp.moveTo(cx + x, y);
          first = false;
        } else {
          wp.lineTo(cx + x, y);
        }
      }
      canvas.drawPath(wp, waveP);
    }

    final Paint bubP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * k
      ..color = UiColors.rgba(220, 250, 255, 0.35 * wf);
    for (final _Bubble b in _bub) {
      b.y -= b.v * dt;
      if (b.y < -0.05) {
        b.y = 1.05;
        b.x = _rnd.nextDouble() * 1.4 - 0.7;
      }
      final Offset bp = Offset(
        cx + b.x * rr * 0.8 + math.sin(t * 2 + b.ph) * 3 * k,
        cy + rr * 0.95 - b.y * rr * 1.9,
      );
      canvas.drawCircle(bp, b.s * k, bubP);
    }

    if (lv2 > 0.35 && t - _lastIn > 0.75) {
      _inRip.add(_Ripple(t));
      _lastIn = t;
    }
    _inRip.removeWhere((_Ripple r) => t - r.t >= 1.3);
    for (final _Ripple r in _inRip) {
      final double p = (t - r.t) / 1.3;
      canvas.drawCircle(
        center,
        p * rr * 0.9,
        Paint()
          ..style = PaintingStyle.stroke
          ..blendMode = BlendMode.plus
          ..strokeWidth = 1.4 * k
          ..color = UiColors.rgba(200, 245, 255, (1 - p) * 0.28 * wf),
      );
    }

    canvas.drawCircle(
      center,
      rr * 0.5,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          center,
          rr * 0.5,
          <Color>[
            UiColors.rgba(255, 255, 255, (0.30 + 0.25 * lv2) * wf),
            UiColors.rgba(120, 200, 255, 0.0),
          ],
        ),
    );

    if (_show > 0.01 && img != null) {
      final double d = rr * 1.92;
      final double kk = d / img.width;
      final double x0 = cx - d / 2;
      final double y0 = cy - d / 2;
      final double wob = (1.2 + 3.2 * lv2) * k;
      final Paint ip = Paint()
        ..filterQuality = FilterQuality.low
        ..color = UiColors.rgba(255, 255, 255, _show);
      final double w = img.width.toDouble();
      for (double sy = 0; sy < img.height; sy += 2) {
        final double dx = math.sin(sy * 0.045 + t * 2.2) * wob + math.sin(sy * 0.11 - t * 1.4) * wob * 0.5;
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, sy, w, 2),
          Rect.fromLTWH(x0 + dx, y0 + sy * kk, d, 2 * kk + 0.6),
          ip,
        );
      }
      canvas.drawCircle(
        center,
        rr,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            rr,
            <Color>[
              UiColors.rgba(5, 20, 60, 0.0),
              UiColors.rgba(5, 20, 60, 0.65 * _show),
            ],
            const <double>[0.35, 1.0],
          ),
      );
      final Offset pin = Offset(cx + rr * 0.06, cy - rr * 0.04);
      final double pr = (t * 0.9) % 1.0;
      canvas.drawCircle(
        pin,
        (4 + 18 * pr) * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * k
          ..color = UiColors.rgba(255, 214, 120, (1 - pr) * 0.8 * _show),
      );
      canvas.drawCircle(
        pin,
        5 * k,
        Paint()..color = UiColors.rgba(255, 220, 130, _show),
      );
    }
    canvas.restore();

    // rim + gloss
    canvas.drawCircle(
      center,
      rr - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * k
        ..shader = ui.Gradient.linear(
          Offset(cx - rr, cy - rr),
          Offset(cx + rr, cy + rr),
          <Color>[
            UiColors.rgba(255, 255, 255, 0.7),
            UiColors.rgba(255, 255, 255, 0.08),
            UiColors.rgba(185, 167, 255, 0.35),
          ],
          const <double>[0, 0.5, 1],
        ),
    );
    canvas.save();
    canvas.translate(cx - rr * 0.32, cy - rr * 0.5);
    canvas.rotate(-0.52);
    canvas.scale(1, 0.52);
    canvas.drawCircle(
      Offset.zero,
      rr * 0.5,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          rr * 0.5,
          <Color>[UiColors.rgba(255, 255, 255, 0.5), UiColors.rgba(255, 255, 255, 0.0)],
        ),
    );
    canvas.restore();

    // ---- comets (slow, mostly falling from the top, fade out) -------------
    final double rate = thinking ? 1.6 : 0.45 + lv2 * 1.5;
    _acc += rate * dt;
    while (_acc >= 1) {
      _acc -= 1;
      _spawn(mode, t, r0, size, k);
    }
    final List<_Comet> keep = <_Comet>[];
    final Paint trail = Paint()
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (final _Comet c in _comets) {
      final double age = t - c.born;
      final double p = age / c.life;
      if (p >= 1) continue;
      double x;
      double y;
      if (c.kind == 0) {
        final double a = c.a0 + c.w * age;
        x = cx + math.cos(a) * c.r;
        y = cy + math.sin(a) * c.r;
      } else if (c.kind == 1) {
        final double u = 1 - p;
        x = u * u * c.x0 + 2 * u * p * c.xc + p * p * c.x1;
        y = u * u * c.y0 + 2 * u * p * c.yc + p * p * c.y1;
      } else {
        final double q = math.pow(p, 1.2).toDouble();
        final double rad = c.dir > 0 ? c.rIn + (c.rOut - c.rIn) * q : c.rOut - (c.rOut - c.rIn) * q;
        final double a = c.a0 + c.sw * p;
        x = cx + math.cos(a) * rad;
        y = cy + math.sin(a) * rad;
      }
      c.pts.add(Offset(x, y));
      if (c.pts.length > 26) c.pts.removeAt(0);
      final double al = math.min(1.0, p / 0.15) *
          (p < 0.5 ? 1.0 : math.pow(1 - (p - 0.5) / 0.5, 1.5).toDouble()) *
          0.85;
      double hue(double tt) {
        if (speaking) return const <double>[24.0, 38.0, 50.0, 335.0][c.h4] + tt * 14;
        if (thinking) return (t * 70 + c.hb + tt * 60) % 360;
        return 190 + ((c.hb + tt * 40) % 170);
      }

      final int n = c.pts.length;
      for (int i = 1; i < n; i++) {
        final double tt = i / n;
        trail
          ..strokeWidth = (0.4 + 2.4 * tt) * k
          ..color = UiColors.hsla(hue(tt), 0.9, (60 + 20 * tt) / 100, al * tt * tt * 0.8);
        canvas.drawLine(c.pts[i - 1], c.pts[i], trail);
      }
      final Offset head = Offset(x, y);
      canvas.drawCircle(
        head,
        (7 + 3 * lv2) * k,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = UiColors.hsla(hue(1), 1.0, 0.75, 0.22 * al),
      );
      canvas.drawCircle(
        head,
        3.5 * k,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = UiColors.hsla(hue(1), 1.0, 0.82, 0.5 * al),
      );
      canvas.drawCircle(head, 1.6 * k, Paint()..color = UiColors.rgba(255, 255, 255, 0.8 * al));
      keep.add(c);
    }
    _comets
      ..clear()
      ..addAll(keep.length > 24 ? keep.sublist(keep.length - 24) : keep);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
