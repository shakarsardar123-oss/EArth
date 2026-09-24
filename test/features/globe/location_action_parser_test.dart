// Tests for the OPTIONAL, backward-compatible location metadata parser.
//
// These verify that:
//   • A plain-text response (no metadata) is returned unchanged, action null.
//   • A fenced ```globe/json block is parsed and stripped from the text.
//   • A bare balanced-brace JSON object is parsed and stripped.
//   • Invalid / out-of-range coordinates are rejected (never invented).
import 'package:flutter_test/flutter_test.dart';

import 'package:texo/features/globe/domain/globe_models.dart';
import 'package:texo/features/globe/domain/location_action.dart';

void main() {
  const parser = LocationActionParser();

  group('LocationActionParser', () {
    test('plain text stays plain (backward compatible)', () {
      const text = 'Ukraine is a country in Eastern Europe.';
      final r = parser.parse(text);
      expect(r.text, text);
      expect(r.action, isNull);
    });

    test('empty response yields empty text, no action', () {
      final r = parser.parse('');
      expect(r.text, '');
      expect(r.action, isNull);
    });

    test('fenced globe block is parsed and stripped', () {
      const response = 'Here is Ukraine.\n'
          '```globe\n'
          '{"locationAction":"focus","highlightType":"country",'
          '"countryCode":"UA","label":"Ukraine"}\n'
          '```';
      final r = parser.parse(response);
      expect(r.action, isNotNull);
      expect(r.action!.action, GlobeLocationAction.focus);
      expect(r.action!.highlightType, GlobeHighlightType.country);
      expect(r.action!.countryCode, 'UA');
      // The fenced block must be removed from the human-readable text.
      expect(r.text.contains('```'), isFalse);
      expect(r.text.trim(), 'Here is Ukraine.');
    });

    test('bare JSON object is parsed and stripped', () {
      const response =
          'Kyiv is the capital. {"locationAction":"focus",'
          '"highlightType":"city","latitude":50.45,"longitude":30.52,'
          '"label":"Kyiv"}';
      final r = parser.parse(response);
      expect(r.action, isNotNull);
      expect(r.action!.highlightType, GlobeHighlightType.city);
      final loc = r.action!.toLocation();
      expect(loc, isNotNull);
      expect(loc!.latitude, closeTo(50.45, 1e-9));
      expect(loc.longitude, closeTo(30.52, 1e-9));
      expect(r.text.contains('{'), isFalse);
      expect(r.text.trim(), 'Kyiv is the capital.');
    });

    test('invalid coordinates are rejected (no invented location)', () {
      const response =
          '{"locationAction":"focus","latitude":999,"longitude":999}';
      final r = parser.parse(response);
      // Out-of-range coordinates must not yield an action at all.
      expect(r.action, isNull);
    });

    test('partial coordinates are rejected', () {
      const response = '{"locationAction":"focus","latitude":50.0}';
      final r = parser.parse(response);
      // Latitude without longitude — rejected unless a name/code is present.
      expect(r.action, isNull);
    });

    test('malformed JSON is ignored, text preserved', () {
      const response = 'Broken {not valid json here';
      final r = parser.parse(response);
      expect(r.action, isNull);
      expect(r.text, response);
    });

    test('return_to_center needs no target', () {
      const response = '{"locationAction":"return_to_center"}';
      final r = parser.parse(response);
      expect(r.action, isNotNull);
      expect(r.action!.action, GlobeLocationAction.returnToCenter);
    });
  });
}
