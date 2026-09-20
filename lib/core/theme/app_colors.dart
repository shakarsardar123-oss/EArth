import 'package:flutter/material.dart';

/// AURA color palette — Violet/Purple design system.
///
/// All theme colors are centralized here so that every widget
/// and future theme extension references a single source of truth.
/// Redesigned per reference images: deep black/navy backgrounds,
/// vibrant violet/purple gradients, frosted glass cards,
/// cyan+magenta neural fiber orb, glass-morphic UI.
class AppColors {
  AppColors._();

  // ── Background layers (deep black/navy) ──
  static const Color background = Color(0xFF0A0A12);
  static const Color card = Color(0xFF151520);
  static const Color secondary = Color(0xFF10101A);
  static const Color surfaceVariant = Color(0xFF1A1A2E);

  // ── Violet / Purple accent spectrum ──
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetLight = Color(0xFFA78BFA);
  static const Color violetDark = Color(0xFF5B21B6);
  static const Color purple = Color(0xFF9333EA);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color purpleDark = Color(0xFF6B21A8);
  static const Color magenta = Color(0xFFD946EF);
  static const Color indigo = Color(0xFF6366F1);

  // ── Orb gradient colors ──
  static const Color orbStart = Color(0xFF7C3AED);
  static const Color orbMiddle = Color(0xFF9333EA);
  static const Color orbEnd = Color(0xFFD946EF);
  static const Color orbGlow = Color(0x407C3AED); // 25% opacity violet glow

  // ── Orb neural fiber colors (cyan + magenta swirling fibers) ──
  static const Color orbCyan = Color(0xFF00E5FF);
  static const Color orbCyanLight = Color(0xFF62FFFF);
  static const Color orbMagenta = Color(0xFFD946EF);
  static const Color orbMagentaLight = Color(0xFFF0ABFC);
  static const Color orbFiberCore = Color(0xFFE0E7FF); // bright white-blue core
  static const Color orbBloomGlow = Color(0x3000E5FF); // cyan bloom

  // ── Wireframe / geometric background overlay ──
  static const Color wireframeLine = Color(0x0DFFFFFF); // 5% white — very subtle
  static const Color wireframeNode = Color(0x1AFFFFFF); // 10% white — dots
  static const Color wireframeAccent = Color(0x0A00E5FF); // subtle cyan accent

  // ── Glass / frosted ──
  static const Color glassBackground = Color(0x1AFFFFFF); // 10% white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white
  static const Color glassHighlight = Color(0x0DFFFFFF); // 5% white
  static const Color glassInputBackground = Color(0x10FFFFFF); // 6% white — chat input glass

  // ── Supporting colors ──
  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanLight = Color(0xFF62FFFF);
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color blue = Color(0xFF448AFF);
  static const Color orange = Color(0xFFFFAB40);
  static const Color green = Color(0xFF69F0AE);
  static const Color red = Color(0xFFFF5252);
  static const Color gold = Color(0xFFFFD700);

  // ── Semantic defaults ──
  static const Color primary = violet;
  static const Color onBackground = Color(0xFFE8E8F0);
  static const Color onCard = Color(0xFFD0D0DC);
  static const Color hint = Color(0xFF6B6B80);
  static const Color border = Color(0xFF1E1E30);
  static const Color divider = Color(0xFF1E1E30);
  static const Color error = red;
  static const Color surface = card;
  static const Color onSurface = onCard;

  // ── Chat bubble colors ──
  static const Color chatBubbleUser = Color(0xFF7C3AED);
  static const Color chatBubbleUserSurface = Color(0xFF1E103A);
  static const Color chatBubbleAI = Color(0xFF1A1A2E);
  static const Color chatInputBackground = Color(0xFF151520);

  // ── Chat bubble user gradient (frosted glass purple) ──
  static const Color chatBubbleUserGradientStart = Color(0xB37C3AED); // 70% violet
  static const Color chatBubbleUserGradientEnd = Color(0x8C9333EA); // 55% purple

  // ── Send button gradient (magenta) ──
  static const Color sendGradientStart = Color(0xFFD946EF); // magenta
  static const Color sendGradientEnd = Color(0xFF9333EA); // purple

  // ── Listening mode voice button gradient ──
  static const Color voiceButtonGradientStart = Color(0xFFD946EF); // magenta
  static const Color voiceButtonGradientEnd = Color(0xFF7C3AED); // violet

  // ── AMOLED pure black ──
  static const Color amoledBlack = Color(0xFF000000);

  // ── Wave Form colors (Reference Image 1) ──
  static const Color waveFormCyan = Color(0xFF00E5FF);
  static const Color waveFormGlow = Color(0x4000E5FF); // 25% cyan glow
  static const Color waveFormBarColor = Color(0xFF00E5FF);
  static const Color waveFormBarDim = Color(0x6600E5FF); // 40% dim bar
  static const Color waveFormErrorRed = Color(0xFFFF4444);
  static const Color waveFormPillBg = Color(0x20000000); // 12% black pill bg
  static const Color waveFormPillBorder = Color(0x3300E5FF); // 20% cyan border

  // ── Floating nav bar ──
  static const Color navBarBackground = Color(0xFF151520);
  static const Color navBarActive = violet;
  static const Color navBarInactive = Color(0xFF6B6B80);
}