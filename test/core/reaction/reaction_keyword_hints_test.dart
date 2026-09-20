import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/reaction/reaction.dart';

void main() {
  group('ReactionKeywordHint', () {
    test('creates with required fields', () {
      final hint = ReactionKeywordHint(
        keyword: 'یارمەتی',
        language: 'ckb',
        category: 'agent',
        tags: ['feedback'],
        boost: 0.15,
      );

      expect(hint.keyword, 'یارمەتی');
      expect(hint.language, 'ckb');
      expect(hint.category, 'agent');
      expect(hint.tags, ['feedback']);
      expect(hint.boost, 0.15);
    });

    test('equality based on keyword, language, category', () {
      final a = ReactionKeywordHint(
        keyword: 'help', language: 'en', category: 'agent',
      );
      final b = ReactionKeywordHint(
        keyword: 'help', language: 'en', category: 'agent',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality with different keyword', () {
      final a = ReactionKeywordHint(
        keyword: 'help', language: 'en', category: 'agent',
      );
      final b = ReactionKeywordHint(
        keyword: 'search', language: 'en', category: 'agent',
      );
      expect(a, isNot(b));
    });

    test('default boost is 0.1', () {
      final hint = ReactionKeywordHint(
        keyword: 'test', language: 'en', category: 'test',
      );
      expect(hint.boost, 0.1);
    });

    test('toString contains keyword and language', () {
      final hint = ReactionKeywordHint(
        keyword: 'سڵاو', language: 'ckb', category: 'personality',
      );
      expect(hint.toString(), contains('سڵاو'));
      expect(hint.toString(), contains('ckb'));
    });
  });

  group('ReactionKeywordHintRegistry', () {
    late ReactionKeywordHintRegistry registry;

    setUp(() {
      registry = ReactionKeywordHintRegistry();
    });

    test('starts empty', () {
      expect(registry.count, 0);
      expect(registry.all, isEmpty);
    });

    test('register adds hint', () {
      registry.register(ReactionKeywordHint(
        keyword: 'test', language: 'en', category: 'test',
      ));
      expect(registry.count, 1);
    });

    test('registerAll adds multiple hints', () {
      registry.registerAll([
        ReactionKeywordHint(keyword: 'a', language: 'en', category: 'x'),
        ReactionKeywordHint(keyword: 'b', language: 'ckb', category: 'y'),
      ]);
      expect(registry.count, 2);
    });

    test('findByKeyword returns matching hints (case-insensitive)', () {
      registry.register(ReactionKeywordHint(
        keyword: 'Hello', language: 'en', category: 'personality',
      ));
      expect(registry.findByKeyword('hello').length, 1);
      expect(registry.findByKeyword('HELLO').length, 1);
      expect(registry.findByKeyword('goodbye').length, 0);
    });

    test('findByLanguage returns matching hints', () {
      registry.registerAll([
        ReactionKeywordHint(keyword: 'a', language: 'ckb', category: 'x'),
        ReactionKeywordHint(keyword: 'b', language: 'en', category: 'y'),
        ReactionKeywordHint(keyword: 'c', language: 'ckb', category: 'z'),
      ]);
      expect(registry.findByLanguage('ckb').length, 2);
      expect(registry.findByLanguage('en').length, 1);
      expect(registry.findByLanguage('fr').length, 0);
    });

    test('findByCategory returns matching hints', () {
      registry.registerAll([
        ReactionKeywordHint(keyword: 'a', language: 'en', category: 'agent'),
        ReactionKeywordHint(keyword: 'b', language: 'en', category: 'error'),
        ReactionKeywordHint(keyword: 'c', language: 'en', category: 'agent'),
      ]);
      expect(registry.findByCategory('agent').length, 2);
      expect(registry.findByCategory('error').length, 1);
    });

    test('computeBoost with matching category', () {
      registry.register(ReactionKeywordHint(
        keyword: 'help', language: 'en', category: 'agent', boost: 0.15,
      ));
      final boost = registry.computeBoost(
        detectedKeywords: ['help'],
        reactionCategory: 'agent',
        reactionTags: [],
      );
      expect(boost, 0.15);
    });

    test('computeBoost with matching tags', () {
      registry.register(ReactionKeywordHint(
        keyword: 'hello', language: 'en', category: 'personality',
        tags: ['greeting'], boost: 0.2,
      ));
      final boost = registry.computeBoost(
        detectedKeywords: ['hello'],
        reactionCategory: 'agent',
        reactionTags: ['greeting'],
      );
      expect(boost, 0.2);
    });

    test('computeBoost with no match returns 0', () {
      registry.register(ReactionKeywordHint(
        keyword: 'help', language: 'en', category: 'agent',
      ));
      final boost = registry.computeBoost(
        detectedKeywords: ['search'],
        reactionCategory: 'agent',
        reactionTags: [],
      );
      expect(boost, 0.0);
    });

    test('computeBoost caps at 1.0', () {
      for (var i = 0; i < 15; i++) {
        registry.register(ReactionKeywordHint(
          keyword: 'kw$i', language: 'en', category: 'agent', boost: 0.2,
        ));
      }
      final boost = registry.computeBoost(
        detectedKeywords: List.generate(15, (i) => 'kw$i'),
        reactionCategory: 'agent',
        reactionTags: [],
      );
      expect(boost, 1.0);
    });

    test('clear removes all hints', () {
      registry.registerAll(defaultCkbHints);
      expect(registry.count, greaterThan(0));
      registry.clear();
      expect(registry.count, 0);
    });
  });

  group('defaultCkbHints', () {
    test('contains Kurdish Sorani keywords', () {
      expect(defaultCkbHints, isNotEmpty);
      expect(defaultCkbHints.every((h) => h.language == 'ckb'), isTrue);
    });

    test('has expected keyword count', () {
      expect(defaultCkbHints.length, 10);
    });

    test('contains یارمەتی (help)', () {
      expect(
        defaultCkbHints.any((h) => h.keyword == 'یارمەتی'),
        isTrue,
      );
    });

    test('contains سڵاو (greeting)', () {
      expect(
        defaultCkbHints.any((h) => h.keyword == 'سڵاو'),
        isTrue,
      );
    });
  });

  group('defaultEnHints', () {
    test('contains English keywords', () {
      expect(defaultEnHints, isNotEmpty);
      expect(defaultEnHints.every((h) => h.language == 'en'), isTrue);
    });

    test('has expected keyword count', () {
      expect(defaultEnHints.length, 8);
    });

    test('contains help', () {
      expect(
        defaultEnHints.any((h) => h.keyword == 'help'),
        isTrue,
      );
    });
  });
}
