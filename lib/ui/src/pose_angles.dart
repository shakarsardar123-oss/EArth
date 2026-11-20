import 'dart:math' as math;

/// A 2D point (x, y) taken from pose landmarks.
class P2 {
  const P2(this.x, this.y);
  final double x;
  final double y;
}

/// Angle at joint [b] formed by points [a]-[b]-[c], in degrees (0..180).
/// Returns NaN when a point coincides with [b].
double jointAngle(P2 a, P2 b, P2 c) {
  final abx = a.x - b.x;
  final aby = a.y - b.y;
  final cbx = c.x - b.x;
  final cby = c.y - b.y;
  final na = math.sqrt(abx * abx + aby * aby);
  final nc = math.sqrt(cbx * cbx + cby * cby);
  if (na == 0 || nc == 0) return double.nan;
  final cosV = ((abx * cbx + aby * cby) / (na * nc)).clamp(-1.0, 1.0);
  return math.acos(cosV) * 180 / math.pi;
}

/// True when [angle] is inside [min]..[max] (inclusive). NaN is never inside.
bool angleInRange(double angle, double min, double max) =>
    angle >= min && angle <= max;
