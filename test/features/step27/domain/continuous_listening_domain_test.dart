/// continuous_listening_domain_test.dart
/// Step 27 structural validation — Continuous Listening domain layer.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Continuous Listening Domain', () {
    test('ListeningVerdict.unknown.isDenied is true', () {
      expect(ListeningVerdict.unknown.isDenied, isTrue);
    });

    test('SegmentationMode.hybrid is default', () {
      expect(SegmentationMode.hybrid, SegmentationMode.hybrid);
    });

    test('ListeningState.unknown is denied', () {
      expect(ListeningState.unknown.isDenied, isTrue);
    });
  });
}
