/// globe_models.dart
/// AURA — Globe domain models.
///
/// Pure, dependency-free value types describing WHAT the globe should show.
/// They contain NO rendering, NO AI, and NO network code, so they are cheap
/// to unit-test. Real geographic coordinates are supplied by the caller
/// (agent pipeline / validated model metadata) — nothing here invents places.
library;

import 'package:flutter/foundation.dart';

/// What kind of geographic entity a highlight represents.
enum GlobeHighlightType { none, country, region, city }

/// High-level action the globe should perform in response to a request.
enum GlobeLocationAction {
  /// No globe action (ordinary text response).
  none,

  /// Rotate + zoom to a location and highlight it.
  focus,

  /// Zoom further into the already-focused location.
  zoomIn,

  /// Clear highlight and smoothly return to the centered idle view.
  returnToCenter,
}

/// A single geographic point with a human-readable label.
///
/// [latitude] is clamped to [-90, 90] and [longitude] to [-180, 180] at
/// construction so an out-of-range value can never reach the renderer.
@immutable
class GlobeLocation {
  GlobeLocation({
    required this.label,
    required double latitude,
    required double longitude,
    this.countryCode,
  })  : latitude = _clampLat(latitude),
        longitude = _clampLon(longitude);

  final String label;
  final double latitude;
  final double longitude;

  /// ISO 3166-1 alpha-2 code when known (e.g. 'UA', 'IQ'). Optional.
  final String? countryCode;

  static double _clampLat(double v) => v.clamp(-90.0, 90.0).toDouble();
  static double _clampLon(double v) => v.clamp(-180.0, 180.0).toDouble();

  /// True when the raw coordinates are finite and in range — callers should
  /// reject anything that fails this before building a [GlobeLocation].
  static bool isValidCoordinate(double lat, double lon) =>
      lat.isFinite &&
      lon.isFinite &&
      lat >= -90.0 &&
      lat <= 90.0 &&
      lon >= -180.0 &&
      lon <= 180.0;

  GlobeLocation copyWith({String? label, String? countryCode}) => GlobeLocation(
        label: label ?? this.label,
        latitude: latitude,
        longitude: longitude,
        countryCode: countryCode ?? this.countryCode,
      );

  @override
  bool operator ==(Object other) =>
      other is GlobeLocation &&
      other.label == label &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(label, latitude, longitude, countryCode);

  @override
  String toString() =>
      'GlobeLocation($label, $latitude, $longitude, cc=$countryCode)';
}

/// A named region defined by a representative center point plus an
/// approximate angular radius (in degrees) used only to size the highlight
/// ring. A region is intentionally fuzzy: it never asserts a precise legal
/// border. Use this for cultural / geographic / historical areas where exact
/// boundaries are contested or not meaningful.
@immutable
class GlobeRegion {
  GlobeRegion({
    required this.label,
    required this.center,
    double approxRadiusDegrees = 3.0,
    this.disclaimer,
  }) : approxRadiusDegrees = approxRadiusDegrees.clamp(0.5, 30.0).toDouble();

  final String label;
  final GlobeLocation center;

  /// Approximate angular extent for the (soft) highlight ring only.
  final double approxRadiusDegrees;

  /// Optional neutral-wording note surfaced with the region (e.g. that
  /// boundaries are approximate / not an assertion of borders).
  final String? disclaimer;

  @override
  bool operator ==(Object other) =>
      other is GlobeRegion &&
      other.label == label &&
      other.center == center &&
      other.approxRadiusDegrees == approxRadiusDegrees &&
      other.disclaimer == disclaimer;

  @override
  int get hashCode =>
      Object.hash(label, center, approxRadiusDegrees, disclaimer);
}

/// Whether the side content/image panel is open, and how far the globe has
/// slid toward the right to make room for it (0 = centered, 1 = fully slid).
@immutable
class GlobeInteractionState {
  const GlobeInteractionState({
    this.action = GlobeLocationAction.none,
    this.location,
    this.region,
    this.highlightType = GlobeHighlightType.none,
    this.zoom = 1.0,
    this.label,
    this.imagePanelOpen = false,
    this.offersMoreInfo = false,
    this.offersImages = false,
  });

  final GlobeLocationAction action;
  final GlobeLocation? location;
  final GlobeRegion? region;
  final GlobeHighlightType highlightType;

  /// Zoom multiplier (1.0 = whole globe). Clamped by the controller.
  final double zoom;

  /// Label to show with the connector line (falls back to location.label).
  final String? label;

  final bool imagePanelOpen;

  /// UI may offer "do you want more info?" / "do you want to see images?".
  final bool offersMoreInfo;
  final bool offersImages;

  /// The idle, centered state (no highlight, panel closed).
  static const GlobeInteractionState idle = GlobeInteractionState();

  GlobeInteractionState copyWith({
    GlobeLocationAction? action,
    GlobeLocation? location,
    bool clearLocation = false,
    GlobeRegion? region,
    bool clearRegion = false,
    GlobeHighlightType? highlightType,
    double? zoom,
    String? label,
    bool clearLabel = false,
    bool? imagePanelOpen,
    bool? offersMoreInfo,
    bool? offersImages,
  }) {
    return GlobeInteractionState(
      action: action ?? this.action,
      location: clearLocation ? null : (location ?? this.location),
      region: clearRegion ? null : (region ?? this.region),
      highlightType: highlightType ?? this.highlightType,
      zoom: zoom ?? this.zoom,
      label: clearLabel ? null : (label ?? this.label),
      imagePanelOpen: imagePanelOpen ?? this.imagePanelOpen,
      offersMoreInfo: offersMoreInfo ?? this.offersMoreInfo,
      offersImages: offersImages ?? this.offersImages,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlobeInteractionState &&
      other.action == action &&
      other.location == location &&
      other.region == region &&
      other.highlightType == highlightType &&
      other.zoom == zoom &&
      other.label == label &&
      other.imagePanelOpen == imagePanelOpen &&
      other.offersMoreInfo == offersMoreInfo &&
      other.offersImages == offersImages;

  @override
  int get hashCode => Object.hash(
        action,
        location,
        region,
        highlightType,
        zoom,
        label,
        imagePanelOpen,
        offersMoreInfo,
        offersImages,
      );
}
