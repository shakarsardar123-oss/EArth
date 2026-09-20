import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Frosted glass card with blur backdrop, semi-transparent background,
/// frosted border, and high-radius rounded corners (28px default).
///
/// This replaces the solid-color AuraCard with a glass-morphism effect
/// matching the reference design — deep black/navy backgrounds with
/// translucent overlaid cards that let background gradients show through.
/// Updated: default corner radius increased from 20 to 28 per reference.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.padding,
    this.borderRadius,
    this.showGlow = false,
    this.glowColor,
    this.onTap,
    this.margin,
    this.width,
    this.height,
    this.blurSigma = 10.0,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool showGlow;
  final Color? glowColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  /// Blur sigma for BackdropFilter. Higher = more frosted.
  final double blurSigma;

  /// Override background color (defaults to AppColors.glassBackground).
  final Color? backgroundColor;

  /// Override border color (defaults to AppColors.glassBorder).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? 28.0;
    final bgColor = backgroundColor ?? AppColors.glassBackground;
    final brdColor = borderColor ?? AppColors.glassBorder;
    final glow = showGlow
        ? (glowColor ?? AppColors.orbGlow.withValues(alpha: 0.3))
        : Colors.transparent;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(
                color: brdColor,
                width: 0.5,
              ),
              boxShadow: showGlow
                  ? [
                      BoxShadow(
                        color: glow,
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(r),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(r),
                child: Padding(
                  padding: padding ?? AppSpacing.cardPadding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}