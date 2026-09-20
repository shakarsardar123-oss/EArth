import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('ReactionCatalog', () {
    late ReactionCatalog catalog;

    setUp(() {
      catalog = ReactionCatalog();
    });

    test('starts empty', () {
      expect(catalog.count, 0);
      expect(catalog.all, isEmpty);
      expect(catalog.ids, isEmpty);
    });

    test('register and get', () {
      final reaction = Reaction(
        id: 'test_1',
        type: const EmojiReactionType('🧪'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      );
      catalog.register(reaction);

      expect(catalog.count, 1);
      expect(catalog.has('test_1'), isTrue);
      expect(catalog.get('test_1'), same(reaction));
    });

    test('getOrThrow throws for missing id', () {
      expect(() => catalog.getOrThrow('missing'), throwsStateError);
    });

    test('getOrThrow returns reaction when present', () {
      final reaction = Reaction(
        id: 'present',
        type: const TextReactionType(),
        trigger: ReactionTrigger.agentState,
        priority: 0.5,
      );
      catalog.register(reaction);

      expect(catalog.getOrThrow('present'), same(reaction));
    });

    test('unregister removes reaction', () {
      final reaction = Reaction(
        id: 'remove_me',
        type: const EmojiReactionType('🗑️'),
        trigger: ReactionTrigger.errorEvent,
        priority: 0.5,
      );
      catalog.register(reaction);
      expect(catalog.has('remove_me'), isTrue);

      catalog.unregister('remove_me');
      expect(catalog.has('remove_me'), isFalse);
      expect(catalog.count, 0);
    });

    test('register overwrites existing id', () {
      final r1 = Reaction(
        id: 'dup',
        type: const EmojiReactionType('1️⃣'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.3,
      );
      final r2 = Reaction(
        id: 'dup',
        type: const EmojiReactionType('2️⃣'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.7,
      );
      catalog.register(r1);
      catalog.register(r2);

      expect(catalog.count, 1);
      expect(catalog.get('dup')!.priority, 0.7);
    });

    test('getByTrigger filters correctly', () {
      catalog.register(Reaction(
        id: 'v1',
        type: const EmojiReactionType('🎤'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      ));
      catalog.register(Reaction(
        id: 'a1',
        type: const EmojiReactionType('🤖'),
        trigger: ReactionTrigger.agentState,
        priority: 0.5,
      ));
      catalog.register(Reaction(
        id: 'v2',
        type: const TextReactionType(),
        trigger: ReactionTrigger.voiceState,
        priority: 0.6,
      ));

      final voiceReactions = catalog.getByTrigger(ReactionTrigger.voiceState);
      expect(voiceReactions.length, 2);
      expect(voiceReactions.every((r) => r.trigger == ReactionTrigger.voiceState), isTrue);
    });

    test('getByCategory filters correctly', () {
      catalog.register(Reaction(
        id: 'cat_voice',
        type: const EmojiReactionType('🎤'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
        category: 'voice',
      ));
      catalog.register(Reaction(
        id: 'cat_agent',
        type: const EmojiReactionType('🤖'),
        trigger: ReactionTrigger.agentState,
        priority: 0.5,
        category: 'agent',
      ));

      expect(catalog.getByCategory('voice').length, 1);
      expect(catalog.getByCategory('agent').length, 1);
      expect(catalog.getByCategory('nonexistent').length, 0);
    });

    test('getByTags filters correctly', () {
      catalog.register(Reaction(
        id: 'tagged',
        type: const EmojiReactionType('🏷️'),
        trigger: ReactionTrigger.idleTimeout,
        priority: 0.5,
        tags: ['idle_hint', 'personality'],
      ));
      catalog.register(Reaction(
        id: 'untagged',
        type: const TextReactionType(),
        trigger: ReactionTrigger.idleTimeout,
        priority: 0.5,
        tags: ['feedback'],
      ));

      expect(catalog.getByTags(['idle_hint']).length, 1);
      expect(catalog.getByTags(['personality']).length, 1);
      expect(catalog.getByTags(['feedback']).length, 1);
      expect(catalog.getByTags(['nonexistent']).length, 0);
    });

    test('getByTriggerAndCategory combines filters', () {
      catalog.register(Reaction(
        id: 'combo',
        type: const EmojiReactionType('🎯'),
        trigger: ReactionTrigger.toolExecution,
        priority: 0.5,
        category: 'tool',
      ));
      catalog.register(Reaction(
        id: 'nope',
        type: const EmojiReactionType('❌'),
        trigger: ReactionTrigger.toolExecution,
        priority: 0.5,
        category: 'other',
      ));

      final result = catalog.getByTriggerAndCategory(
        ReactionTrigger.toolExecution,
        'tool',
      );
      expect(result.length, 1);
      expect(result.first.id, 'combo');
    });

    test('clear removes all reactions', () {
      for (var i = 0; i < 5; i++) {
        catalog.register(Reaction(
          id: 'r_$i',
          type: EmojiReactionType('$i'),
          trigger: ReactionTrigger.voiceState,
          priority: 0.5,
        ));
      }
      expect(catalog.count, 5);
      catalog.clear();
      expect(catalog.count, 0);
    });

    test('all returns unmodifiable list', () {
      catalog.register(Reaction(
        id: 'immutable',
        type: const EmojiReactionType('🔒'),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      ));

      expect(() => catalog.all.add(Reaction(
        id: 'nope',
        type: const TextReactionType(),
        trigger: ReactionTrigger.voiceState,
        priority: 0.5,
      )), throwsA(isA<UnsupportedError>()));
    });
  });
}
