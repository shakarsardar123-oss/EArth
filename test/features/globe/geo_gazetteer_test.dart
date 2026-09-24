// Tests for the real-coordinate gazetteer. Every value must be a real,
// in-range coordinate; unknown names must return null (no invented data);
// and the Kurdistan reference must be a neutral geographic region with a
// disclaimer, not a political border.
import 'package:flutter_test/flutter_test.dart';

import 'package:texo/features/globe/data/geo_gazetteer.dart';
import 'package:texo/features/globe/domain/globe_models.dart';

void main() {
  const gaz = GeoGazetteer();

  test('resolves Ukraine by name and by code to same real centroid', () {
    final byName = gaz.resolve(name: 'Ukraine');
    final byCode = gaz.resolve(code: 'UA');
    expect(byName, isNotNull);
    expect(byCode, isNotNull);
    expect(byName!.latitude, byCode!.latitude);
    expect(byName.longitude, byCode.longitude);
    expect(GlobeLocation.isValidCoordinate(byName.latitude, byName.longitude),
        isTrue);
  });

  test('Sulaymaniyah uses its real coordinates', () {
    final loc = gaz.resolve(name: 'Sulaymaniyah');
    expect(loc, isNotNull);
    expect(loc!.latitude, closeTo(35.56, 0.05));
    expect(loc.longitude, closeTo(45.43, 0.05));
    expect(loc.countryCode, 'IQ');
  });

  test('unknown name returns null (never invents)', () {
    expect(gaz.resolve(name: 'Atlantis'), isNull);
    expect(gaz.resolve(code: 'ZZ'), isNull);
    expect(gaz.resolve(), isNull);
  });

  test('all named entries carry valid, in-range coordinates', () {
    for (final key in ['ukraine', 'iraq', 'kyiv', 'erbil', 'sulaymaniyah']) {
      final loc = gaz.byName(key);
      expect(loc, isNotNull, reason: 'missing $key');
      expect(
        GlobeLocation.isValidCoordinate(loc!.latitude, loc.longitude),
        isTrue,
        reason: 'invalid coords for $key',
      );
    }
  });

  test('Kurdistan is a neutral geographic region with a disclaimer', () {
    final region = GeoGazetteer.kurdistanRegion();
    expect(region.disclaimer, isNotNull);
    expect(region.disclaimer!.toLowerCase(), contains('not a political'));
    expect(
      GlobeLocation.isValidCoordinate(
          region.center.latitude, region.center.longitude),
      isTrue,
    );
    // A fuzzy area, not a point.
    expect(region.approxRadiusDegrees, greaterThan(0));
  });
}
