import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('ReactionVisualStyle', () {
    test('has all expected values', () {
      expect(ReactionVisualStyle.values, containsAll([
        ReactionVisualStyle.emoji,
        ReactionVisualStyle.pixelArt,
        ReactionVisualStyle.asciiArt,
        ReactionVisualStyle.code,
        ReactionVisualStyle.meme,
        ReactionVisualStyle.customVisual,
      ]));
    });

    test('label returns expected strings', () {
      expect(ReactionVisualStyle.emoji.label, 'emoji');
      expect(ReactionVisualStyle.pixelArt.label, 'pixel_art');
      expect(ReactionVisualStyle.asciiArt.label, 'ascii_art');
      expect(ReactionVisualStyle.code.label, 'code');
      expect(ReactionVisualStyle.meme.label, 'meme');
      expect(ReactionVisualStyle.customVisual.label, 'custom_visual');
    });

    test('isNativeRenderable returns correct values', () {
      expect(ReactionVisualStyle.emoji.isNativeRenderable, isTrue);
      expect(ReactionVisualStyle.pixelArt.isNativeRenderable, isFalse);
      expect(ReactionVisualStyle.asciiArt.isNativeRenderable, isTrue);
      expect(ReactionVisualStyle.code.isNativeRenderable, isFalse);
      expect(ReactionVisualStyle.meme.isNativeRenderable, isFalse);
      expect(ReactionVisualStyle.customVisual.isNativeRenderable, isFalse);
    });
  });

  group('defaultStyleForType', () {
    test('EmojiReactionType maps to emoji style', () {
      expect(
        defaultStyleForType(const EmojiReactionType('🧪')),
        ReactionVisualStyle.emoji,
      );
    });

    test('AnimationReactionType maps to customVisual', () {
      expect(
        defaultStyleForType(const AnimationReactionType('confetti')),
        ReactionVisualStyle.customVisual,
      );
    });

    test('TextReactionType maps to asciiArt', () {
      expect(
        defaultStyleForType(const TextReactionType()),
        ReactionVisualStyle.asciiArt,
      );
    });

    test('HumorReactionType maps to meme', () {
      expect(
        defaultStyleForType(const HumorReactionType()),
        ReactionVisualStyle.meme,
      );
    });

    test('TerminalReactionType maps to code', () {
      expect(
        defaultStyleForType(const TerminalReactionType()),
        ReactionVisualStyle.code,
      );
    });

    test('CodeReactionType maps to code', () {
      expect(
        defaultStyleForType(const CodeReactionType('dart')),
        ReactionVisualStyle.code,
      );
    });

    test('VisualReactionType maps to customVisual', () {
      expect(
        defaultStyleForType(const VisualReactionType()),
        ReactionVisualStyle.customVisual,
      );
    });

    test('NativeOverlayReactionType maps to customVisual', () {
      expect(
        defaultStyleForType(const NativeOverlayReactionType()),
        ReactionVisualStyle.customVisual,
      );
    });
  });
}
