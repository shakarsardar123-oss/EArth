import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('ReactionPresentationType', () {
    test('EmojiReactionType has correct properties', () {
      const type = EmojiReactionType('🧪');
      expect(type.key, 'emoji');
      expect(type.emoji, '🧪');
      expect(type.isNativeRenderable, isTrue);
    });

    test('AnimationReactionType has correct properties', () {
      const type = AnimationReactionType('pulse');
      expect(type.key, 'animation');
      expect(type.animationKey, 'pulse');
      expect(type.isNativeRenderable, isFalse);
    });

    test('TextReactionType has correct properties', () {
      const type = TextReactionType();
      expect(type.key, 'text');
      expect(type.isNativeRenderable, isTrue);
    });

    test('HumorReactionType has correct properties', () {
      const type = HumorReactionType();
      expect(type.key, 'humor');
      expect(type.isNativeRenderable, isFalse);
    });

    test('TerminalReactionType has correct properties', () {
      const type = TerminalReactionType();
      expect(type.key, 'terminal');
      expect(type.isNativeRenderable, isFalse);
    });

    test('CodeReactionType has correct properties', () {
      const type = CodeReactionType('dart');
      expect(type.key, 'code');
      expect(type.language, 'dart');
      expect(type.isNativeRenderable, isFalse);
    });

    test('VisualReactionType has correct properties', () {
      const type = VisualReactionType();
      expect(type.key, 'visual');
      expect(type.isNativeRenderable, isFalse);
    });

    test('NativeOverlayReactionType has correct properties', () {
      const type = NativeOverlayReactionType();
      expect(type.key, 'nativeOverlay');
      expect(type.isNativeRenderable, isTrue);
    });
  });

  group('ReactionPresentationType equality', () {
    test('same type and value are equal', () {
      const a = EmojiReactionType('🔥');
      const b = EmojiReactionType('🔥');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different emoji are not equal', () {
      const a = EmojiReactionType('🔥');
      const b = EmojiReactionType('💧');
      expect(a, isNot(b));
    });

    test('different subtypes with same key string are not equal', () {
      const a = EmojiReactionType('pulse');
      const b = AnimationReactionType('pulse');
      // Different sealed subtypes — never equal
      expect(a, isNot(b));
    });

    test('parameterless types are equal to themselves', () {
      const a = TextReactionType();
      const b = TextReactionType();
      expect(a, b);
    });

    test('parameterless types of different kind are not equal', () {
      const a = TextReactionType();
      const b = HumorReactionType();
      expect(a, isNot(b));
    });

    test('CodeReactionType equality depends on language', () {
      const a = CodeReactionType('dart');
      const b = CodeReactionType('python');
      expect(a, isNot(b));

      const c = CodeReactionType('dart');
      expect(a, c);
    });

    test('switch expression exhaustiveness covers all 8 types', () {
      final types = <ReactionPresentationType>[
        const EmojiReactionType('e'),
        const AnimationReactionType('a'),
        const TextReactionType(),
        const HumorReactionType(),
        const TerminalReactionType(),
        const CodeReactionType('c'),
        const VisualReactionType(),
        const NativeOverlayReactionType(),
      ];

      // Verify switch compiles (exhaustive) and returns expected native flag
      final nativeFlags = <bool>[];
      for (final type in types) {
        final native = switch (type) {
          EmojiReactionType() => type.isNativeRenderable,
          AnimationReactionType() => type.isNativeRenderable,
          TextReactionType() => type.isNativeRenderable,
          HumorReactionType() => type.isNativeRenderable,
          TerminalReactionType() => type.isNativeRenderable,
          CodeReactionType() => type.isNativeRenderable,
          VisualReactionType() => type.isNativeRenderable,
          NativeOverlayReactionType() => type.isNativeRenderable,
        };
        nativeFlags.add(native);
      }

      // Expected: emoji=true, animation=false, text=true, humor=false,
      // terminal=false, code=false, visual=false, nativeOverlay=true
      expect(nativeFlags, [true, false, true, false, false, false, false, true]);
    });
  });
}
