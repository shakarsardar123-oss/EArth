/// geo_gazetteer.dart
/// AURA — A SMALL set of real, verifiable geographic reference points used
/// only to resolve a location NAME to real coordinates when the AI metadata
/// supplies a name but no lat/long. Every coordinate here is a real,
/// well-known approximate centroid — nothing is invented and no borders are
/// asserted. Unknown names simply return null (the globe then does nothing).
///
/// Coordinates are decimal degrees (WGS84), rounded to ~0.1°.
library;

import '../domain/globe_models.dart';

class GeoGazetteer {
  const GeoGazetteer();

  /// Countries by ISO alpha-2 code → approximate centroid.
  static final Map<String, GlobeLocation> _countriesByCode = {
    'UA': GlobeLocation(
        label: 'Ukraine', latitude: 49.0, longitude: 32.0, countryCode: 'UA'),
    'IQ': GlobeLocation(
        label: 'Iraq', latitude: 33.2, longitude: 43.7, countryCode: 'IQ'),
    'IR': GlobeLocation(
        label: 'Iran', latitude: 32.0, longitude: 53.0, countryCode: 'IR'),
    'TR': GlobeLocation(
        label: 'Turkey', latitude: 39.0, longitude: 35.0, countryCode: 'TR'),
    'SY': GlobeLocation(
        label: 'Syria', latitude: 35.0, longitude: 38.0, countryCode: 'SY'),
  };

  /// Named places (lowercased keys, incl. common Sorani/English spellings)
  /// → real coordinates. Cities use their real city coordinates.
  static final Map<String, GlobeLocation> _named = {
    // Countries (name aliases)
    'ukraine': _countriesByCode['UA']!,
    'ئۆکراینا': _countriesByCode['UA']!,
    'iraq': _countriesByCode['IQ']!,
    'عێراق': _countriesByCode['IQ']!,
    // Cities (real coordinates)
    'sulaymaniyah': GlobeLocation(
        label: 'Sulaymaniyah',
        latitude: 35.56,
        longitude: 45.43,
        countryCode: 'IQ'),
    'slemani': GlobeLocation(
        label: 'Sulaymaniyah',
        latitude: 35.56,
        longitude: 45.43,
        countryCode: 'IQ'),
    'سلێمانی': GlobeLocation(
        label: 'سلێمانی',
        latitude: 35.56,
        longitude: 45.43,
        countryCode: 'IQ'),
    'erbil': GlobeLocation(
        label: 'Erbil',
        latitude: 36.19,
        longitude: 44.01,
        countryCode: 'IQ'),
    'hewler': GlobeLocation(
        label: 'Hewlêr',
        latitude: 36.19,
        longitude: 44.01,
        countryCode: 'IQ'),
    'kyiv': GlobeLocation(
        label: 'Kyiv', latitude: 50.45, longitude: 30.52, countryCode: 'UA'),
  };

  /// A neutral, approximate CENTER for the geographic/cultural Kurdistan
  /// region (the area historically associated with Kurdish populations across
  /// parts of Iraq, Iran, Turkey and Syria). This is deliberately a fuzzy
  /// region with a disclaimer — it asserts NO political border.
  static GlobeRegion kurdistanRegion() => GlobeRegion(
        label: 'کوردستان',
        center: GlobeLocation(label: 'کوردستان', latitude: 37.0, longitude: 43.0),
        approxRadiusDegrees: 6.0,
        disclaimer:
            'Geographic/cultural region; approximate area, not a political '
            'border.',
      );

  GlobeLocation? countryByCode(String? code) {
    if (code == null) return null;
    return _countriesByCode[code.toUpperCase()];
  }

  GlobeLocation? byName(String? name) {
    if (name == null) return null;
    return _named[name.trim().toLowerCase()];
  }

  /// Resolve the best real location for an optional name + optional code.
  GlobeLocation? resolve({String? name, String? code}) =>
      byName(name) ?? countryByCode(code);
}
