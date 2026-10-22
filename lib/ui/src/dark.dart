import 'package:flutter/widgets.dart';

/// Dark mode: the whole light UI is drawn through this colour matrix (invert +
/// hue-rotate 180°), so white becomes near-black, black text becomes white and
/// the accent colours stay recognisable. Applying the same matrix twice gives
/// the original colours back, which is how screens that are already dark (Live,
/// the old Vision screen) and pictures (the logo) are kept as they are.
const List<double> kUiDarkMatrix = <double>[
  0.574, -1.430, -0.144, 0, 255, //
  -0.426, -0.430, -0.144, 0, 255, //
  -0.426, -1.430, 0.856, 0, 255, //
  0, 0, 0, 1, 0, //
];

class UiDarkScope extends InheritedWidget {
  const UiDarkScope({super.key, required this.dark, required super.child});

  final bool dark;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiDarkScope>()?.dark ?? false;

  @override
  bool updateShouldNotify(UiDarkScope oldWidget) => dark != oldWidget.dark;
}

/// Shows [child] with its own colours even while the app is in dark mode.
class UiUnfilter extends StatelessWidget {
  const UiUnfilter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!UiDarkScope.of(context)) return child;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(kUiDarkMatrix),
      child: child,
    );
  }
}
