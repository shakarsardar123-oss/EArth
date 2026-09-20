// Tests for GlobeController: verifies it drives DESIRED visual state from
// primitive calls and from parsed LocationActions, resolves names via the
// real gazetteer, and never invents coordinates for unknown names.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_assistant/features/globe/application/globe_controller.dart';
import 'package:aura_assistant/features/globe/domain/globe_models.dart';
import 'package:aura_assistant/features/globe/domain/location_action.dart';

void main() {
  group('GlobeController primitives', () {
    test('starts idle and centered', () {
      final c = GlobeController();
      expect(c.state.highlightType, GlobeHighlightType.none);
      expect(c.targetLongitude, isNull);
      expect(c.targetLatitude, isNull);
      expect(c.targetZoom, 1.0);
      expect(c.panRight, 0.0);
    });

    test('rotateToLocation sets targets for valid coords only', () {
      final c = GlobeController();
      c.rotateToLocation(50.45, 30.52); // Kyiv
      expect(c.targetLatitude, closeTo(50.45, 1e-9));
      expect(c.targetLongitude, closeTo(30.52, 1e-9));

      c.rotateToLocation(999, 999); // invalid — ignored
      expect(c.targetLatitude, closeTo(50.45, 1e-9));
    });

    test('highlightCity focuses and labels', () {
      final c = GlobeController();
      c.highlightCity(GlobeLocation(
          label: 'Kyiv', latitude: 50.45, longitude: 30.52));
      expect(c.state.highlightType, GlobeHighlightType.city);
      expect(c.state.label, 'Kyiv');
      expect(c.targetZoom, greaterThan(1.0));
    });

    test('returnToCenter clears targets and pan', () {
      final c = GlobeController();
      c.highlightCity(GlobeLocation(
          label: 'Kyiv', latitude: 50.45, longitude: 30.52));
      c.openImagePanel();
      expect(c.panRight, 1.0);
      c.returnToCenter();
      expect(c.targetLatitude, isNull);
      expect(c.targetLongitude, isNull);
      expect(c.targetZoom, 1.0);
      expect(c.panRight, 0.0);
      expect(c.state.highlightType, GlobeHighlightType.none);
    });
  });

  group('GlobeController.applyLocationAction', () {
    const parser = LocationActionParser();

    test('focus by country code resolves via gazetteer (Ukraine)', () {
      final c = GlobeController();
      final r = parser.parse(
          '{"locationAction":"focus","highlightType":"country",'
          '"countryCode":"UA"}');
      expect(r.action, isNotNull);
      c.applyLocationAction(r.action!);
      expect(c.state.highlightType, GlobeHighlightType.country);
      // Ukraine centroid ~ (49, 32).
      expect(c.targetLatitude, closeTo(49.0, 0.5));
      expect(c.targetLongitude, closeTo(32.0, 0.5));
    });

    test('focus by explicit coordinates', () {
      final c = GlobeController();
      final r = parser.parse(
          '{"locationAction":"focus","highlightType":"city",'
          '"latitude":35.56,"longitude":45.43,"label":"Sulaymaniyah"}');
      c.applyLocationAction(r.action!);
      expect(c.state.highlightType, GlobeHighlightType.city);
      expect(c.state.label, 'Sulaymaniyah');
      expect(c.targetLatitude, closeTo(35.56, 1e-9));
    });

    test('unknown name does nothing (never invents coords)', () {
      final c = GlobeController();
      final r = parser.parse(
          '{"locationAction":"focus","locationName":"Nowherestan"}');
      // Parser accepts it (name present), controller must not move.
      if (r.action != null) c.applyLocationAction(r.action!);
      expect(c.targetLatitude, isNull);
      expect(c.state.highlightType, GlobeHighlightType.none);
    });

    test('return_to_center recenters', () {
      final c = GlobeController();
      c.highlightCity(GlobeLocation(
          label: 'Kyiv', latitude: 50.45, longitude: 30.52));
      final r = parser.parse('{"locationAction":"return_to_center"}');
      c.applyLocationAction(r.action!);
      expect(c.targetLatitude, isNull);
      expect(c.targetZoom, 1.0);
    });
  });
}
