/// Presentation types for the AURA Dynamic Reaction System.
///
/// Each type determines how a reaction is rendered on the floating
/// overlay or in the app UI. The native Android overlay (plain View)
/// can only render [emoji], [text], and [nativeOverlay]. All other
/// types require Flutter-rendered content (future Step 3+).
///
/// Uses a sealed class (Dart 3) so the compiler enforces exhaustive
/// pattern matching in switch expressions.
library;

/// The kind of visual presentation a [Reaction] can produce.
sealed class ReactionPresentationType {
  const ReactionPresentationType();

  /// Unique string key for serialization / logging.
  String get key;

  /// Whether this type can be rendered on the native Android overlay
  /// (plain View) via MethodChannel without a FlutterView.
  bool get isNativeRenderable;
}

/// Simple emoji shown on the overlay (e.g. "✨", "🤖", "💡").
class EmojiReactionType extends ReactionPresentationType {
  const EmojiReactionType(this.emoji);

  /// The emoji character to display.
  final String emoji;

  @override
  String get key => 'emoji';

  @override
  bool get isNativeRenderable => true;

  @override
  bool operator ==(Object other) =>
      other is EmojiReactionType && other.emoji == emoji;

  @override
  int get hashCode => Object.hash(key, emoji);

  @override
  String toString() => 'EmojiReactionType($emoji)';
}

/// Short animated burst (e.g. confetti, sparkle, pulse).
/// Not natively renderable — future Flutter overlay integration.
class AnimationReactionType extends ReactionPresentationType {
  const AnimationReactionType(this.animationKey);

  /// Logical key for the animation asset (e.g. 'confetti', 'sparkle').
  final String animationKey;

  @override
  String get key => 'animation';

  @override
  bool get isNativeRenderable => false;

  @override
  bool operator ==(Object other) =>
      other is AnimationReactionType && other.animationKey == animationKey;

  @override
  int get hashCode => Object.hash(key, animationKey);

  @override
  String toString() => 'AnimationReactionType($animationKey)';
}

/// Short text bubble shown on the overlay.
class TextReactionType extends ReactionPresentationType {
  const TextReactionType();

  @override
  String get key => 'text';

  @override
  bool get isNativeRenderable => true;

  @override
  bool operator ==(Object other) => other is TextReactionType;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'TextReactionType()';
}

/// Humorous / personality text (Kurdish Sorani first, RTL).
class HumorReactionType extends ReactionPresentationType {
  const HumorReactionType();

  @override
  String get key => 'humor';

  @override
  bool get isNativeRenderable => false;

  @override
  bool operator ==(Object other) => other is HumorReactionType;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'HumorReactionType()';
}

/// Terminal-style feedback (monospace, technical context).
class TerminalReactionType extends ReactionPresentationType {
  const TerminalReactionType();

  @override
  String get key => 'terminal';

  @override
  bool get isNativeRenderable => false;

  @override
  int get hashCode => key.hashCode;

  @override
  bool operator ==(Object other) => other is TerminalReactionType;

  @override
  String toString() => 'TerminalReactionType()';
}

/// Code snippet display (syntax-highlighted, future Flutter rendering).
class CodeReactionType extends ReactionPresentationType {
  const CodeReactionType(this.language);

  /// Programming language key for highlighting (e.g. 'dart', 'python').
  final String language;

  @override
  String get key => 'code';

  @override
  bool get isNativeRenderable => false;

  @override
  bool operator ==(Object other) =>
      other is CodeReactionType && other.language == language;

  @override
  int get hashCode => Object.hash(key, language);

  @override
  String toString() => 'CodeReactionType($language)';
}

/// Rich visual card (image + text, future Flutter rendering).
class VisualReactionType extends ReactionPresentationType {
  const VisualReactionType();

  @override
  String get key => 'visual';

  @override
  bool get isNativeRenderable => false;

  @override
  bool operator ==(Object other) => other is VisualReactionType;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'VisualReactionType()';
}

/// Full native overlay update — the reaction payload is a complete
/// overlay state change sent through MethodChannel.
class NativeOverlayReactionType extends ReactionPresentationType {
  const NativeOverlayReactionType();

  @override
  String get key => 'nativeOverlay';

  @override
  bool get isNativeRenderable => true;

  @override
  bool operator ==(Object other) => other is NativeOverlayReactionType;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'NativeOverlayReactionType()';
}
