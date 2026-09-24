/// Result models for the AURA screen-understanding subsystem.
///
/// [ScreenRepresentation] is the structured output of a screen analysis:
/// visible text items, UI elements, screen regions, and metadata.
library;

import 'package:meta/meta.dart' show immutable;

// ── Enums ────────────────────────────────────────────────────────

/// Classification of detected text in a screen frame.
enum TextType {
  /// Regular body / paragraph text.
  body,

  /// Heading or title text.
  heading,

  /// Button label.
  button,

  /// Link / anchor text.
  link,

  /// Caption or subtitle text.
  caption,

  /// Menu or tab label.
  menuLabel,

  /// Placeholder / hint text (e.g. in text fields).
  placeholder,

  /// Notification / badge text.
  notification,

  /// Tooltip or help text.
  tooltip,

  /// Other / unclassified text.
  other,
}

/// Classification of detected UI elements.
enum UIElementType {
  /// Push button.
  button,

  /// Text input field.
  textField,

  /// Checkbox / toggle switch.
  checkbox,

  /// Radio button.
  radioButton,

  /// Dropdown / select list.
  dropdown,

  /// Slider / range control.
  slider,

  /// Switch / toggle.
  switchControl,

  /// Icon (non-interactive decorative).
  icon,

  /// Image / photo.
  image,

  /// Card / container.
  card,

  /// List item.
  listItem,

  /// Tab bar item.
  tab,

  /// Navigation bar (bottom / top).
  navigationBar,

  /// Toolbar / action bar.
  toolbar,

  /// Dialog / modal.
  dialog,

  /// Floating action button.
  fab,

  /// Chip / tag.
  chip,

  /// Progress indicator.
  progressIndicator,

  /// Scroll view / list.
  scrollView,

  /// Other / unclassified element.
  other,
}

/// Classification of screen regions.
enum ScreenRegionType {
  /// Status bar / system top bar.
  statusBar,

  /// App bar / toolbar / title bar.
  appBar,

  /// Main content area.
  content,

  /// Bottom navigation bar.
  bottomNavigation,

  /// Floating action button area.
  fabRegion,

  /// Side drawer / navigation rail.
  drawer,

  /// Dialog / modal overlay.
  dialogOverlay,

  /// SnackBar / toast area.
  snackbarRegion,

  /// Keyboard / input method area.
  keyboard,

  /// Tab bar region.
  tabBar,

  /// Search bar region.
  searchBar,

  /// Other / unclassified region.
  other,
}

// ── Models ───────────────────────────────────────────────────────

/// A single piece of visible text detected on the screen.
@immutable
class ScreenTextItem {
  const ScreenTextItem({
    required this.text,
    required this.boundingBox,
    this.confidence = 1.0,
    this.language,
    this.textType = TextType.other,
  });

  /// The visible text content.
  final String text;

  /// Normalized bounding box (0.0–1.0) of the text region.
  final TextBoundingBox boundingBox;

  /// Detection confidence (0.0–1.0).
  final double confidence;

  /// Detected language code (e.g. 'ku', 'en', 'ar').
  final String? language;

  /// Classification of the text.
  final TextType textType;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'text': text,
        'bounding_box': boundingBox.toJson(),
        'confidence': confidence,
        'language': language,
        'text_type': textType.name,
      };

  @override
  String toString() =>
      'ScreenTextItem("$text", type: ${textType.name}, conf: $confidence)';
}

/// Lightweight normalized bounding box for screen-understanding results.
///
/// Unlike [BoundingBox] in the vision domain, this is a minimal
/// rectangle with no styling or overlay fields.
@immutable
class TextBoundingBox {
  const TextBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// X position (0–1, left edge).
  final double x;

  /// Y position (0–1, top edge).
  final double y;

  /// Width (0–1).
  final double width;

  /// Height (0–1).
  final double height;

  /// Center X.
  double get cx => x + width / 2;

  /// Center Y.
  double get cy => y + height / 2;

  /// Right edge.
  double get right => x + width;

  /// Bottom edge.
  double get bottom => y + height;

  /// Area (0–1).
  double get area => width * height;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  @override
  String toString() =>
      'TextBoundingBox(x: $x, y: $y, w: $width, h: $height)';
}

/// A single UI element detected on the screen.
@immutable
class UIElement {
  const UIElement({
    required this.type,
    required this.boundingBox,
    this.label,
    this.confidence = 1.0,
    this.isEnabled = true,
    this.isSelected = false,
  });

  /// Type of UI element.
  final UIElementType type;

  /// Normalized bounding box (0.0–1.0).
  final TextBoundingBox boundingBox;

  /// Accessible label or visible text of the element.
  final String? label;

  /// Detection confidence (0.0–1.0).
  final double confidence;

  /// Whether the element appears enabled / interactive.
  final bool isEnabled;

  /// Whether the element appears selected / checked.
  final bool isSelected;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'bounding_box': boundingBox.toJson(),
        'label': label,
        'confidence': confidence,
        'is_enabled': isEnabled,
        'is_selected': isSelected,
      };

  @override
  String toString() =>
      'UIElement(${type.name}, label: "$label", conf: $confidence)';
}

/// A named region of the screen layout.
@immutable
class ScreenRegion {
  const ScreenRegion({
    required this.type,
    required this.boundingBox,
    this.confidence = 1.0,
  });

  /// Type of screen region.
  final ScreenRegionType type;

  /// Normalized bounding box (0.0–1.0).
  final TextBoundingBox boundingBox;

  /// Detection confidence (0.0–1.0).
  final double confidence;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'bounding_box': boundingBox.toJson(),
        'confidence': confidence,
      };

  @override
  String toString() =>
      'ScreenRegion(${type.name}, conf: $confidence)';
}

/// Metadata about the analyzed screen frame.
@immutable
class ScreenMetadata {
  const ScreenMetadata({
    required this.timestamp,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.appName,
    this.appPackage,
    this.overallConfidence = 1.0,
    this.modelUsed,
    this.processingTimeMs,
  });

  /// Epoch-millis timestamp of the analyzed frame.
  final int timestamp;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Rotation (0, 90, 180, 270).
  final int rotation;

  /// Name of the foreground app, if known.
  final String? appName;

  /// Package name of the foreground app, if known.
  final String? appPackage;

  /// Overall confidence of the analysis (0.0–1.0).
  final double overallConfidence;

  /// Model used for the analysis (e.g. 'gpt-4o').
  final String? modelUsed;

  /// Processing time in milliseconds.
  final int? processingTimeMs;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'width': width,
        'height': height,
        'rotation': rotation,
        'app_name': appName,
        'app_package': appPackage,
        'overall_confidence': overallConfidence,
        'model_used': modelUsed,
        'processing_time_ms': processingTimeMs,
      };

  @override
  String toString() =>
      'ScreenMetadata(${width}x$height, rotation: $rotation, '
      'conf: $overallConfidence)';
}

/// Complete structured representation of a screen frame.
///
/// This is the primary output of the Screen Understanding subsystem.
/// It contains all detected text, UI elements, regions, and metadata.
@immutable
class ScreenRepresentation {
  const ScreenRepresentation({
    required this.metadata,
    this.textItems = const [],
    this.uiElements = const [],
    this.regions = const [],
  });

  /// Metadata about the analyzed frame.
  final ScreenMetadata metadata;

  /// All visible text items found on the screen.
  final List<ScreenTextItem> textItems;

  /// All UI elements detected on the screen.
  final List<UIElement> uiElements;

  /// Named screen regions (top bar, content, nav, etc.).
  final List<ScreenRegion> regions;

  /// Number of text items detected.
  int get textItemCount => textItems.length;

  /// Number of UI elements detected.
  int get uiElementCount => uiElements.length;

  /// Number of regions detected.
  int get regionCount => regions.length;

  /// Whether any content was detected.
  bool get hasContent =>
      textItems.isNotEmpty || uiElements.isNotEmpty || regions.isNotEmpty;

  /// All text concatenated (for full-text search / TTS).
  String get fullText =>
      textItems.map((t) => t.text).join(' ');

  /// Average confidence across all detections.
  double get averageConfidence {
    final allConfidences = <double>[
      ...textItems.map((t) => t.confidence),
      ...uiElements.map((u) => u.confidence),
      ...regions.map((r) => r.confidence),
    ];
    if (allConfidences.isEmpty) return 0.0;
    return allConfidences.reduce((a, b) => a + b) / allConfidences.length;
  }

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'text_items': textItems.map((t) => t.toJson()).toList(),
        'ui_elements': uiElements.map((u) => u.toJson()).toList(),
        'regions': regions.map((r) => r.toJson()).toList(),
      };

  @override
  String toString() =>
      'ScreenRepresentation(texts: $textItemCount, '
      'ui: $uiElementCount, regions: $regionCount, '
      'conf: ${averageConfidence.toStringAsFixed(2)})';
}
