/// Visual style categories for the AURA Dynamic Reaction System.
///
/// [ReactionVisualStyle] classifies the **aesthetic family** of a
/// reaction's visual output. This is orthogonal to [ReactionPresentationType]
/// (which defines the *rendering method*: emoji, text, animation, etc.)
/// and [ReactionTone] (which defines the *emotional tone*).
///
/// A visual style describes **how** a reaction should look aesthetically:
/// emoji-based, pixel-art, ASCII art, code-style, meme-style, or custom.
/// The style-aware selector uses this to rotate styles and prevent
/// visual monotony (e.g. avoiding showing emoji after emoji).
///
/// Step 4 scope: classification ONLY. No rendering, no image assets,
/// no UI changes.
library;

import 'reaction_type.dart';

/// The aesthetic visual style of a reaction's output.
///
/// Used by the variation engine and style-aware selector to ensure
/// visual diversity across consecutive reactions.
enum ReactionVisualStyle {
  /// Standard emoji presentation (e.g. 👂, ✨, ⚙️).
  /// Maps naturally to [EmojiReactionType].
  emoji,

  /// Pixel-art aesthetic — retro / 8-bit styled output.
  /// Future rendering; here it's a classification only.
  pixelArt,

  /// ASCII / text-art representation.
  /// Maps naturally to [TerminalReactionType] and [TextReactionType].
  asciiArt,

  /// Code / syntax-highlighted technical display.
  /// Maps naturally to [CodeReactionType] and [TerminalReactionType].
  code,

  /// Meme / humorous visual style (extensible, no hardcoded jokes).
  /// Maps naturally to [HumorReactionType].
  meme,

  /// Custom / user-defined visual style — extensible catch-all.
  /// Maps naturally to [VisualReactionType] and [NativeOverlayReactionType].
  customVisual;

  /// Human-readable label for this style.
  String get label => switch (this) {
        ReactionVisualStyle.emoji => 'emoji',
        ReactionVisualStyle.pixelArt => 'pixel_art',
        ReactionVisualStyle.asciiArt => 'ascii_art',
        ReactionVisualStyle.code => 'code',
        ReactionVisualStyle.meme => 'meme',
        ReactionVisualStyle.customVisual => 'custom_visual',
      };

  /// Whether this style can be rendered on the native Android overlay.
  /// Only emoji and asciiArt are native-renderable (plain View).
  bool get isNativeRenderable => switch (this) {
        ReactionVisualStyle.emoji => true,
        ReactionVisualStyle.pixelArt => false,
        ReactionVisualStyle.asciiArt => true,
        ReactionVisualStyle.code => false,
        ReactionVisualStyle.meme => false,
        ReactionVisualStyle.customVisual => false,
      };
}

/// Utility for mapping [ReactionPresentationType] to a default
/// [ReactionVisualStyle].
///
/// This mapping is used when a [Reaction] doesn't explicitly specify
/// a visual style (backward compatibility with Step 2 definitions).
ReactionVisualStyle defaultStyleForType(ReactionPresentationType type) {
  return switch (type) {
    EmojiReactionType() => ReactionVisualStyle.emoji,
    AnimationReactionType() => ReactionVisualStyle.customVisual,
    TextReactionType() => ReactionVisualStyle.asciiArt,
    HumorReactionType() => ReactionVisualStyle.meme,
    TerminalReactionType() => ReactionVisualStyle.code,
    CodeReactionType() => ReactionVisualStyle.code,
    VisualReactionType() => ReactionVisualStyle.customVisual,
    NativeOverlayReactionType() => ReactionVisualStyle.customVisual,
  };
}
