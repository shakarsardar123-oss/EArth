import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'colors.dart';

/// Light (0), soft light (1) or dark Live (2) screen background.
class UiBackground extends StatelessWidget {
  const UiBackground({super.key, required this.kind, required this.child});

  final int kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Gradient gradient;
    if (kind == 0) {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          UiColors.lightTop,
          UiColors.lightMid,
          UiColors.lightLow,
          UiColors.lightBottom,
        ],
        stops: <double>[0, 0.38, 0.76, 1],
      );
    } else if (kind == 1) {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[UiColors.lightTop, UiColors.softMid, UiColors.softBottom],
        stops: <double>[0, 0.6, 1],
      );
    } else {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[UiColors.liveTop, UiColors.liveMid, UiColors.liveBottom],
        stops: <double>[0, 0.52, 1],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}

/// The TEXO app logo (falls back to a gradient square if the asset is missing).
class TexoLogo extends StatelessWidget {
  const TexoLogo({super.key, this.size = 84, this.radius = 20, this.shadow = true});

  final double size;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? const <BoxShadow>[
                BoxShadow(color: Color(0x4746AAAA), blurRadius: 28, offset: Offset(0, 10)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/logo/texo_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext c, Object e, StackTrace? s) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF3B6FE0), UiColors.violet],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade + slide + scale entrance after an optional delay.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double e = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: e,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - e)),
            child: Transform.scale(scale: 0.96 + 0.04 * e, child: child),
          ),
        );
      },
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path p = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.62, h * 0.38)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.62, h * 0.62)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.38, h * 0.62)
      ..lineTo(0, h * 0.5)
      ..lineTo(w * 0.38, h * 0.38)
      ..close();
    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w, h),
        const <Color>[Color(0xFFFFFFFF), Color(0xFFFBBF24), Color(0xFFF472B6)],
        const <double>[0, 0.6, 1],
      );
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A suggestion "question" card: rainbow border that keeps turning, appears
/// out of a blur, with sparkles that twinkle around it.
class MagicCard extends StatefulWidget {
  const MagicCard({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.delay = Duration.zero,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<MagicCard> createState() => _MagicCardState();
}

class _MagicCardState extends State<MagicCard> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _enter.dispose();
    _spin.dispose();
    super.dispose();
  }

  Widget _spark(double phase) {
    final double t = (_spin.value * 2.5 + phase) % 1.0;
    final double a = t < 0.45 ? t / 0.45 : (t < 0.7 ? 1 - (t - 0.45) / 0.25 : 0.0);
    return IgnorePointer(
      child: Opacity(
        opacity: a.clamp(0.0, 1.0).toDouble(),
        child: Transform.rotate(
          angle: t * math.pi / 2,
          child: Transform.scale(
            scale: 0.2 + 0.8 * a,
            child: CustomPaint(size: const Size(13, 13), painter: _StarPainter()),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: SweepGradient(
                colors: UiColors.rainbow,
                transform: GradientRotation(_spin.value * 2 * math.pi),
              ),
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xEDFFFFFF),
                borderRadius: BorderRadius.circular(18.5),
              ),
              child: Row(
                children: <Widget>[
                  Icon(widget.icon, size: 26, color: UiColors.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: const TextStyle(fontSize: 16.5, height: 1.5, color: UiColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(end: 16, top: -6, child: _spark(0.0)),
        PositionedDirectional(start: 34, bottom: -6, child: _spark(0.45)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_enter, _spin]),
      builder: (BuildContext context, Widget? _) {
        final double e = Curves.easeOutCubic.transform(_enter.value);
        Widget card = _card();
        if (e < 1) {
          final double sigma = 10 * (1 - e) + 0.001;
          card = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: card,
          );
        }
        return Opacity(
          opacity: e,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - e)),
            child: Transform.scale(scale: 0.95 + 0.05 * e, child: card),
          ),
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * dx, 0.0, 0.0);
  }
}

/// Text that materialises with a rainbow shimmer passing through it once.
class RevealText extends StatefulWidget {
  const RevealText(this.text, {super.key, required this.style, this.animate = false});

  final String text;
  final TextStyle style;
  final bool animate;

  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return Text(widget.text, style: widget.style);
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) {
        if (_c.isCompleted) return Text(widget.text, style: widget.style);
        final double t = Curves.easeOut.transform(_c.value);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect rect) => LinearGradient(
            colors: const <Color>[
              UiColors.ink,
              UiColors.ink,
              Color(0xFF8B5CF6),
              Color(0xFFEC4899),
              Color(0xFF38BDF8),
              UiColors.ink,
              UiColors.ink,
            ],
            stops: const <double>[0, 0.36, 0.46, 0.5, 0.54, 0.64, 1],
            transform: _SlideGradient(1 - 2 * t),
          ).createShader(rect),
          child: Text(widget.text, style: widget.style.copyWith(color: Colors.white)),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: UiColors.rainbow,
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(rect);
    canvas.drawCircle(rect.center, 10, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}

/// Small spinning rainbow ring shown while the assistant works.
class ThinkingRing extends StatefulWidget {
  const ThinkingRing({super.key});

  @override
  State<ThinkingRing> createState() => _ThinkingRingState();
}

class _ThinkingRingState extends State<ThinkingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) =>
          CustomPaint(size: const Size(26, 26), painter: _RingPainter(_c.value)),
    );
  }
}

/// Round glass button used on the dark Live screen.
class GlassCircle extends StatelessWidget {
  const GlassCircle({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 52,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x14FFFFFF),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Icon(icon, color: UiColors.liveInk, size: size * 0.42),
        ),
      ),
    );
  }
}

/// 44x44 tappable icon with a label for accessibility.
class UiIconButton extends StatelessWidget {
  const UiIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = UiColors.ink,
    this.background,
    this.size = 24,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: background == null
              ? null
              : BoxDecoration(shape: BoxShape.circle, color: background),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
