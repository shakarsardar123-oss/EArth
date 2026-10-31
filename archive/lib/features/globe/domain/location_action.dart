/// location_action.dart
/// AURA — Backward-compatible structured location metadata for AI responses.
///
/// The AgentEngine returns plain text today. This adds an OPTIONAL, validated
/// metadata layer: a response MAY embed a small JSON object describing a globe
/// action. If it does not, everything keeps working as plain text.
///
/// Contract (all fields optional except `locationAction`):
///   {
///     "locationAction": "focus",      // focus | zoom_in | return_to_center
///     "locationName": "Ukraine",
///     "countryCode": "UA",
///     "latitude": 49.0,
///     "longitude": 32.0,
///     "zoom": 4,
///     "highlightType": "country",     // country | region | city
///     "label": "Ukraine",
///     "showImagesOffer": true,
///     "panelAction": "open"           // open | close (optional)
///   }
///
/// SECURITY: only these known scalar fields are read. No URLs are executed,
/// no code is evaluated, and every numeric field is range-validated. Unknown
/// keys are ignored.
library;

import 'dart:convert';

import 'globe_models.dart';

/// Result of parsing an AI response: the always-present [text] plus an
/// OPTIONAL, already-validated [action]. [action] is null for ordinary
/// responses or when embedded metadata failed validation.
class ParsedAiResponse {
  const ParsedAiResponse({required this.text, this.action});

  /// Human-readable text with any metadata block stripped out. Never null;
  /// equals the original response when no metadata was present.
  final String text;

  /// Validated globe action, or null.
  final LocationAction? action;

  bool get hasAction => action != null;
}

/// Panel side-effect requested by the model.
enum PanelAction { none, open, close }

/// A validated globe action extracted from a response. Construction goes
/// through [tryParseMap] so an instance is always internally consistent.
class LocationAction {
  const LocationAction._({
    required this.action,
    required this.highlightType,
    required this.panelAction,
    this.locationName,
    this.countryCode,
    this.latitude,
    this.longitude,
    this.zoom,
    this.label,
    this.showImagesOffer = false,
    this.showMoreInfoOffer = false,
  });

  final GlobeLocationAction action;
  final GlobeHighlightType highlightType;
  final PanelAction panelAction;
  final String? locationName;
  final String? countryCode;
  final double? latitude;
  final double? longitude;
  final double? zoom;
  final String? label;
  final bool showImagesOffer;
  final bool showMoreInfoOffer;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Build a [GlobeLocation] when coordinates are present and valid.
  GlobeLocation? toLocation() {
    if (!hasCoordinates) return null;
    if (!GlobeLocation.isValidCoordinate(latitude!, longitude!)) return null;
    return GlobeLocation(
      label: label ?? locationName ?? '',
      latitude: latitude!,
      longitude: longitude!,
      countryCode: countryCode,
    );
  }

  static GlobeLocationAction _actionFrom(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'focus':
        return GlobeLocationAction.focus;
      case 'zoom_in':
      case 'zoomin':
      case 'zoom':
        return GlobeLocationAction.zoomIn;
      case 'return_to_center':
      case 'center':
      case 'clear':
        return GlobeLocationAction.returnToCenter;
      default:
        return GlobeLocationAction.none;
    }
  }

  static GlobeHighlightType _highlightFrom(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'country':
        return GlobeHighlightType.country;
      case 'region':
        return GlobeHighlightType.region;
      case 'city':
        return GlobeHighlightType.city;
      default:
        return GlobeHighlightType.none;
    }
  }

  static PanelAction _panelFrom(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'open':
        return PanelAction.open;
      case 'close':
        return PanelAction.close;
      default:
        return PanelAction.none;
    }
  }

  static double? _numOrNull(Object? v) {
    if (v is num) {
      final d = v.toDouble();
      return d.isFinite ? d : null;
    }
    if (v is String) {
      final d = double.tryParse(v.trim());
      return (d != null && d.isFinite) ? d : null;
    }
    return null;
  }

  static String? _strOrNull(Object? v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  /// Validate a decoded JSON map into a [LocationAction], or null if it is
  /// not a usable globe action. Coordinates, when present, MUST be valid.
  static LocationAction? tryParseMap(Map<String, dynamic> map) {
    final action = _actionFrom(map['locationAction'] as String?);
    final panel = _panelFrom(map['panelAction'] as String?);
    // Nothing actionable — don't manufacture an action.
    if (action == GlobeLocationAction.none && panel == PanelAction.none) {
      return null;
    }

    final lat = _numOrNull(map['latitude']);
    final lon = _numOrNull(map['longitude']);
    // If coordinates are supplied they must be in range; reject partial or
    // out-of-range coordinates rather than guessing.
    if (lat != null || lon != null) {
      if (lat == null || lon == null) return null;
      if (!GlobeLocation.isValidCoordinate(lat, lon)) return null;
    }

    // A focus/zoom action is only meaningful with a target.
    if ((action == GlobeLocationAction.focus ||
            action == GlobeLocationAction.zoomIn) &&
        lat == null &&
        _strOrNull(map['locationName']) == null &&
        _strOrNull(map['countryCode']) == null) {
      return null;
    }

    double? zoom = _numOrNull(map['zoom']);
    if (zoom != null) zoom = zoom.clamp(1.0, 12.0).toDouble();

    String? cc = _strOrNull(map['countryCode']);
    if (cc != null) {
      cc = cc.toUpperCase();
      if (cc.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(cc)) cc = null;
    }

    return LocationAction._(
      action: action,
      highlightType: _highlightFrom(map['highlightType'] as String?),
      panelAction: panel,
      locationName: _strOrNull(map['locationName']),
      countryCode: cc,
      latitude: lat,
      longitude: lon,
      zoom: zoom,
      label: _strOrNull(map['label']),
      showImagesOffer: map['showImagesOffer'] == true,
      showMoreInfoOffer: map['showMoreInfoOffer'] == true,
    );
  }
}

/// Parses an AI response string into [ParsedAiResponse]. Backward compatible:
/// when no valid metadata block is found, [ParsedAiResponse.text] is the
/// original string and [ParsedAiResponse.action] is null.
///
/// Supported embeddings (first valid one wins):
///   1. A fenced block:  ```globe { ... } ```  or  ```json { ... } ```
///   2. A bare trailing/embedded JSON object containing "locationAction".
class LocationActionParser {
  const LocationActionParser();

  static final RegExp _fenced = RegExp(
    r'```(?:globe|json)?\s*(\{[\s\S]*?\})\s*```',
    caseSensitive: false,
  );

  ParsedAiResponse parse(String response) {
    if (response.isEmpty) return const ParsedAiResponse(text: '');

    // 1) Fenced block.
    final fence = _fenced.firstMatch(response);
    if (fence != null) {
      final action = _tryDecode(fence.group(1)!);
      if (action != null) {
        final text = response.replaceRange(fence.start, fence.end, '').trim();
        return ParsedAiResponse(text: text, action: action);
      }
    }

    // 2) Bare JSON object that mentions locationAction. Scan balanced braces
    //    around the keyword so surrounding prose is preserved.
    final idx = response.indexOf('"locationAction"');
    if (idx != -1) {
      final span = _enclosingObject(response, idx);
      if (span != null) {
        final action = _tryDecode(response.substring(span[0], span[1]));
        if (action != null) {
          final text =
              response.replaceRange(span[0], span[1], '').trim();
          return ParsedAiResponse(text: text, action: action);
        }
      }
    }

    // No metadata — plain text (backward compatible).
    return ParsedAiResponse(text: response);
  }

  LocationAction? _tryDecode(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        return LocationAction.tryParseMap(decoded);
      }
    } catch (_) {
      // Malformed metadata — ignore, keep plain text.
    }
    return null;
  }

  /// Returns [start, end) of the smallest brace-balanced object containing
  /// [anchor], or null if braces are unbalanced.
  List<int>? _enclosingObject(String s, int anchor) {
    int start = anchor;
    while (start >= 0 && s[start] != '{') {
      start--;
    }
    if (start < 0) return null;
    int depth = 0;
    for (int i = start; i < s.length; i++) {
      final c = s[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) return [start, i + 1];
      }
    }
    return null;
  }
}
