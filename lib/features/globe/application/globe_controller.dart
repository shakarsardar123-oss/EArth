/// globe_controller.dart
/// AURA — GlobeController.
///
/// The single, thin control surface the agent / UI uses to drive the globe.
/// It stores the DESIRED visual state ([GlobeInteractionState]) plus target
/// rotation/zoom/pan values and notifies listeners; the renderer animates
/// toward these targets. It does NOT call any AI provider, does NOT geocode,
/// and does NOT interpret speech — callers pass already-resolved data.
///
/// Continuous idle spin is LEFT-only and owned by the renderer; this
/// controller never introduces random motion.
library;

import 'package:flutter/foundation.dart';

import '../data/geo_gazetteer.dart';
import '../domain/globe_models.dart';
import '../domain/location_action.dart';

class GlobeController extends ChangeNotifier {
  GlobeController({GeoGazetteer? gazetteer})
      : _gazetteer = gazetteer ?? const GeoGazetteer();

  final GeoGazetteer _gazetteer;

  GlobeInteractionState _state = GlobeInteractionState.idle;
  GlobeInteractionState get state => _state;

  // Target the renderer animates toward. Longitude/latitude in degrees.
  double? _targetLon;
  double? _targetLat;
  double _targetZoom = 1.0;
  double _panRight = 0.0; // 0 = centered, 1 = slid right for the panel.

  double? get targetLongitude => _targetLon;
  double? get targetLatitude => _targetLat;
  double get targetZoom => _targetZoom;
  double get panRight => _panRight;

  static const double _maxZoom = 12.0;

  void _set(GlobeInteractionState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  // ── Primitive movements ──────────────────────────────────────────

  /// Rotate to face a real coordinate (no zoom change).
  void rotateToLocation(double latitude, double longitude) {
    if (!GlobeLocation.isValidCoordinate(latitude, longitude)) return;
    _targetLat = latitude;
    _targetLon = longitude;
    notifyListeners();
  }

  /// Rotate AND zoom to a real coordinate.
  void zoomToLocation(double latitude, double longitude, {double zoom = 4.0}) {
    if (!GlobeLocation.isValidCoordinate(latitude, longitude)) return;
    _targetLat = latitude;
    _targetLon = longitude;
    _targetZoom = zoom.clamp(1.0, _maxZoom).toDouble();
    _set(_state.copyWith(zoom: _targetZoom));
  }

  // ── Highlights ───────────────────────────────────────────────────

  void highlightCountry(GlobeLocation country) {
    _focus(country,
        type: GlobeHighlightType.country, zoom: 4.0, label: country.label);
  }

  void highlightRegion(GlobeRegion region) {
    _targetLat = region.center.latitude;
    _targetLon = region.center.longitude;
    _targetZoom = 5.0;
    _set(_state.copyWith(
      action: GlobeLocationAction.focus,
      region: region,
      location: region.center,
      highlightType: GlobeHighlightType.region,
      zoom: _targetZoom,
      label: region.label,
    ));
  }

  void highlightCity(GlobeLocation city) {
    _focus(city,
        type: GlobeHighlightType.city, zoom: 7.0, label: city.label);
  }

  void _focus(GlobeLocation loc,
      {required GlobeHighlightType type,
      required double zoom,
      String? label}) {
    _targetLat = loc.latitude;
    _targetLon = loc.longitude;
    _targetZoom = zoom.clamp(1.0, _maxZoom).toDouble();
    _set(_state.copyWith(
      action: GlobeLocationAction.focus,
      location: loc,
      clearRegion: true,
      highlightType: type,
      zoom: _targetZoom,
      label: label ?? loc.label,
    ));
  }

  /// Update only the visible label (e.g. connector-line caption).
  void showLocationLabel(String name) {
    _set(_state.copyWith(label: name));
  }

  /// Zoom further into the current target (used for "more info").
  void zoomIn({double factor = 1.6}) {
    _targetZoom = (_targetZoom * factor).clamp(1.0, _maxZoom).toDouble();
    _set(_state.copyWith(action: GlobeLocationAction.zoomIn, zoom: _targetZoom));
  }

  void clearHighlight() {
    _set(_state.copyWith(
      action: GlobeLocationAction.none,
      clearLocation: true,
      clearRegion: true,
      highlightType: GlobeHighlightType.none,
      clearLabel: true,
      offersMoreInfo: false,
      offersImages: false,
    ));
  }

  /// Smoothly return to the centered idle view (keeps left rotation).
  void returnToCenter() {
    _targetLat = null;
    _targetLon = null;
    _targetZoom = 1.0;
    _panRight = 0.0;
    _set(GlobeInteractionState.idle);
  }

  // ── Image / content panel ────────────────────────────────────────

  /// Slide the globe toward the right and open the panel (globe stays
  /// partially visible; it is never pushed fully off-screen).
  void openImagePanel() {
    _panRight = 1.0;
    _set(_state.copyWith(imagePanelOpen: true));
  }

  /// Close the panel and slide the globe back to center.
  void closeImagePanel() {
    _panRight = 0.0;
    _set(_state.copyWith(imagePanelOpen: false));
  }

  // ── Offers surfaced by the UI ────────────────────────────────────

  void setOffers({bool? moreInfo, bool? images}) {
    _set(_state.copyWith(offersMoreInfo: moreInfo, offersImages: images));
  }

  // ── High-level entry point from a parsed AI response ─────────────

  /// Apply a validated [LocationAction]. Names without coordinates are
  /// resolved via the small real gazetteer; unknown names are ignored
  /// (the globe simply does nothing rather than guessing).
  void applyLocationAction(LocationAction a) {
    switch (a.action) {
      case GlobeLocationAction.returnToCenter:
        returnToCenter();
        break;
      case GlobeLocationAction.zoomIn:
        // Prefer explicit target if given, else just zoom current.
        final loc = a.toLocation() ??
            _gazetteer.resolve(name: a.locationName, code: a.countryCode);
        if (loc != null) {
          zoomToLocation(loc.latitude, loc.longitude,
              zoom: (a.zoom ?? _targetZoom * 1.6));
        } else {
          zoomIn();
        }
        break;
      case GlobeLocationAction.focus:
        final loc = a.toLocation() ??
            _gazetteer.resolve(name: a.locationName, code: a.countryCode);
        if (loc == null) break; // unknown — do nothing, never invent.
        final labelled =
            (a.label != null) ? loc.copyWith(label: a.label) : loc;
        switch (a.highlightType) {
          case GlobeHighlightType.city:
            highlightCity(labelled);
            break;
          case GlobeHighlightType.region:
            highlightRegion(GlobeRegion(
                label: a.label ?? labelled.label, center: labelled));
            break;
          case GlobeHighlightType.country:
          case GlobeHighlightType.none:
            highlightCountry(labelled);
            break;
        }
        if (a.zoom != null) {
          _targetZoom = a.zoom!.clamp(1.0, _maxZoom).toDouble();
          _set(_state.copyWith(zoom: _targetZoom));
        }
        break;
      case GlobeLocationAction.none:
        break;
    }

    if (a.showImagesOffer || a.showMoreInfoOffer) {
      setOffers(
          moreInfo: a.showMoreInfoOffer ? true : null,
          images: a.showImagesOffer ? true : null);
    }
    switch (a.panelAction) {
      case PanelAction.open:
        openImagePanel();
        break;
      case PanelAction.close:
        closeImagePanel();
        break;
      case PanelAction.none:
        break;
    }
  }
}
