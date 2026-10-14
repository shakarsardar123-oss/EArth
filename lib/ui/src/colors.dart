import 'package:flutter/material.dart';

/// Colour tokens of the TEXO design (light screens + dark Live screen).
class UiColors {
  UiColors._();

  static const Color ink = Color(0xFF1B1B1F);
  static const Color inkSoft = Color(0xFF5F6068);
  static const Color inkFaint = Color(0xFF6F6F78);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetBubble = Color(0xFF6D3FE0);
  static const Color violetText = Color(0xFF5B4BC4);
  static const Color skyBubble = Color(0xFFDCE9FB);
  static const Color skyInk = Color(0xFF10213D);
  static const Color pill = Color(0xFFD3E6FB);
  static const Color pillInk = Color(0xFF14213D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color segTrack = Color(0xFFE9EEF7);
  static const Color switchOff = Color(0xFFB9BFCC);

  static const Color lightTop = Color(0xFFFAFAFA);
  static const Color lightMid = Color(0xFFF7F9FC);
  static const Color lightLow = Color(0xFFDCEAFB);
  static const Color lightBottom = Color(0xFFB6D5F7);
  static const Color softMid = Color(0xFFF4F7FC);
  static const Color softBottom = Color(0xFFE6EFFB);

  static const Color liveTop = Color(0xFF14163A);
  static const Color liveMid = Color(0xFF241E52);
  static const Color liveBottom = Color(0xFF46264F);
  static const Color liveInk = Color(0xFFEDEAF8);
  static const Color liveSoft = Color(0xFFC4BEE4);

  static const List<Color> rainbow = <Color>[
    Color(0xFFF472B6),
    Color(0xFFA78BFA),
    Color(0xFF38BDF8),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFFF472B6),
  ];

  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12285096), blurRadius: 14, offset: Offset(0, 3)),
  ];

  static Color rgba(int r, int g, int b, double a) =>
      Color.fromRGBO(r, g, b, a < 0 ? 0 : (a > 1 ? 1 : a));

  /// [s] and [l] are 0..1, [h] in degrees.
  static Color hsla(double h, double s, double l, double a) {
    final double hue = ((h % 360) + 360) % 360;
    final double alpha = a < 0 ? 0 : (a > 1 ? 1 : a);
    return HSLColor.fromAHSL(alpha, hue, s, l).toColor();
  }
}
