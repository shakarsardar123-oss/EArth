import 'package:flutter_test/flutter_test.dart';
import 'package:texo/ui/src/pose_angles.dart';

void main() {
  test('right angle is 90 degrees', () {
    final a = jointAngle(const P2(1, 0), const P2(0, 0), const P2(0, 1));
    expect(a, closeTo(90, 1e-6));
  });

  test('straight line is 180 degrees', () {
    final a = jointAngle(const P2(-1, 0), const P2(0, 0), const P2(1, 0));
    expect(a, closeTo(180, 1e-6));
  });

  test('coincident point gives NaN and is never in range', () {
    final a = jointAngle(const P2(0, 0), const P2(0, 0), const P2(1, 0));
    expect(a.isNaN, isTrue);
    expect(angleInRange(a, 0, 180), isFalse);
  });

  test('range check is inclusive', () {
    expect(angleInRange(90, 90, 120), isTrue);
    expect(angleInRange(89.9, 90, 120), isFalse);
  });
}
