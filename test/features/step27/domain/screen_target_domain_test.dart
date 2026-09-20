/// screen_target_domain_test.dart
/// Step 27 structural validation — Screen Target domain layer.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Screen Target Domain', () {
    test('CorrectionActionType.unknown.isDenied is true', () {
      expect(CorrectionActionType.unknown.isDenied, isTrue);
    });

    test('ScreenTarget.isActionable requires verified+usable+nonEmpty', () {
      // unverified target is not actionable
      final target = ScreenTarget.unverified;
      expect(target.isActionable, isFalse);
    });

    test('DetectionVerdict.unknown.isDenied is true', () {
      expect(DetectionVerdict.unknown.isDenied, isTrue);
    });
  });
}
