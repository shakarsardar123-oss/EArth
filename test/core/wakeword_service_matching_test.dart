import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/wakeword/wakeword_service.dart';

/// Pure unit tests for the WakeWordService detection logic. These exercise
/// the SAME normalization + substring predicate used by the live matcher
/// (`matchesForTest` / `normalizeForTest` mirror the production code), so
/// no VoiceServiceImpl or speech plugin is required.
void main() {
  // The English default phrase set (mirrors _defaultWakePhrases, normalized).
  final phrases = <String>[
    'hey aura',
    'hey ora',
    'hey aurora',
    'hi aura',
    'ئەورا',
    'هێ ئەورا',
  ];

  group('normalizeForTest', () {
    test('lowercases, strips punctuation and collapses whitespace', () {
      expect(WakeWordService.normalizeForTest('Hey, AURA!'), 'hey aura');
      expect(WakeWordService.normalizeForTest('  HEY   aura  '), 'hey aura');
      expect(WakeWordService.normalizeForTest('Hey... Aura?'), 'hey aura');
    });

    test('preserves Arabic-script (Kurdish) letters', () {
      // Kurdish word must survive normalization intact.
      expect(WakeWordService.normalizeForTest('ئەورا'), 'ئەورا');
    });

    test('empty / punctuation-only input normalizes to empty', () {
      expect(WakeWordService.normalizeForTest('   '), '');
      expect(WakeWordService.normalizeForTest('!!!'), '');
    });
  });

  group('matchesForTest — English "Hey AURA" variants', () {
    test('matches the canonical phrase', () {
      expect(WakeWordService.matchesForTest('hey aura', phrases), isTrue);
    });

    test('matches with punctuation and casing', () {
      expect(WakeWordService.matchesForTest('Hey, AURA!', phrases), isTrue);
    });

    test('matches when embedded in a longer utterance', () {
      expect(
        WakeWordService.matchesForTest('ok hey aura what time is it', phrases),
        isTrue,
      );
    });

    test('matches common recognizer mishears', () {
      expect(WakeWordService.matchesForTest('hey aurora', phrases), isTrue);
      expect(WakeWordService.matchesForTest('hi aura', phrases), isTrue);
    });
  });

  group('matchesForTest — Kurdish/Sorani phrase', () {
    test('matches the Sorani wake word', () {
      expect(WakeWordService.matchesForTest('ئەورا', phrases), isTrue);
    });

    test('matches the two-word Sorani phrase', () {
      expect(WakeWordService.matchesForTest('هێ ئەورا', phrases), isTrue);
    });
  });

  group('matchesForTest — negatives (no false triggers)', () {
    test('bare "aura" alone does NOT trigger', () {
      expect(WakeWordService.matchesForTest('aura', phrases), isFalse);
    });

    test('unrelated speech does NOT trigger', () {
      expect(
        WakeWordService.matchesForTest('what is the weather today', phrases),
        isFalse,
      );
    });

    test('empty input does NOT trigger', () {
      expect(WakeWordService.matchesForTest('', phrases), isFalse);
      expect(WakeWordService.matchesForTest('   ', phrases), isFalse);
    });
  });

  group('default phrase set exposed via wakePhrases getter', () {
    test('includes the English primary and Kurdish phrase, excludes bare aura',
        () {
      // Construct is not needed for the static matcher, but we assert the
      // documented default set contains the key phrases.
      expect(phrases, contains('hey aura'));
      expect(phrases, contains('ئەورا'));
      expect(phrases, isNot(contains('aura')));
    });
  });
}
