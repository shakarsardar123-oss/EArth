import 'package:flutter/material.dart';

/// Responsive breakpoints for AURA.
///
/// Usage:
/// ```dart
/// final layout = ResponsiveLayout.of(context);
/// if (layout.isMobile) { ... }
/// ```
class ResponsiveLayout {
  ResponsiveLayout._({required this.breakpoint});

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  final double breakpoint;

  bool get isMobile => breakpoint < mobileBreakpoint;
  bool get isTablet => breakpoint >= mobileBreakpoint && breakpoint < desktopBreakpoint;
  bool get isDesktop => breakpoint >= desktopBreakpoint;
  bool get isCompact => breakpoint < mobileBreakpoint;
  bool get isMedium => breakpoint >= mobileBreakpoint && breakpoint < tabletBreakpoint;
  bool get isExpanded => breakpoint >= tabletBreakpoint;

  /// Number of grid columns for card layouts.
  int get gridColumns {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 3;
  }

  /// Horizontal padding for screen edges.
  double get horizontalPadding {
    if (isMobile) return 16;
    if (isTablet) return 24;
    return 32;
  }

  /// Max content width for centered layouts.
  double get maxContentWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 600;
    return 800;
  }

  static ResponsiveLayout of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ResponsiveLayout._(breakpoint: width);
  }
}

/// Builder that provides different widgets for different screen sizes.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    final layout = ResponsiveLayout.of(context);
    if (layout.isDesktop && desktop != null) {
      return desktop!(context);
    }
    if (layout.isTablet && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}
