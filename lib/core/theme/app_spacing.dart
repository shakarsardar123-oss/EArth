import 'package:flutter/material.dart';

/// Centralized spacing, radius, and elevation constants for AURA.
///
/// Use these instead of hardcoded values to ensure visual consistency.
/// Updated: added xxl=24 and xxxl=32 for reference-matching high-radius corners.
class AppSpacing {
  AppSpacing._();

  // ── Spacing scale ──
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
  static const double huge = 64.0;

  // ── Common insets ──
  static const EdgeInsets screenPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: lg, vertical: sm);
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(horizontal: lg, vertical: xl);
}

class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 28.0;
  static const double pill = 100.0;
}

class AppElevation {
  AppElevation._();

  static const double none = 0.0;
  static const double sm = 1.0;
  static const double md = 3.0;
  static const double lg = 6.0;
  static const double xl = 12.0;
}