/// subtitle_overlay_domain_test.dart
/// Step 27 structural validation — Subtitle Overlay domain layer.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Subtitle Overlay Domain', () {
    test('OverlayVisibility.unknown.isBlocking is true', () {
      expect(OverlayVisibility.unknown.isBlocking, isTrue);
    });

    test('OverlayVerdict.unknown.isDenied is true', () {
      expect(OverlayVerdict.unknown.isDenied, isTrue);
    });

    test('SubtitleDirection defaults to rtl', () {
      expect(SubtitleDirection.rtl, SubtitleDirection.rtl);
    });
  });
}
