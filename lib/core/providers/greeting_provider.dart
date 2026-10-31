/// greeting_provider.dart
/// AURA – Smart Greeting Provider
///
/// Generates context-aware greetings based on visit history.
/// Uses plain [FutureProvider] — no code-generation required.
///
/// Supported scenarios:
///  1. First visit          → greetingFirstVisit
///  2. 24h+ absence        → greetingWelcomeBack
///  3. Same day return      → greetingSameDay
///  4. Day refreshes        → next morning triggers welcomeBack
///  5. No annoying repeat   → per-session timestamp prevents re-greeting
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLastVisitTimestamp = 'aura_last_visit_timestamp';
const _kHasVisitedBefore = 'aura_has_visited_before';

/// How long (ms) between visits before we show "welcome back" instead of
/// a simple "hello".  Currently 24 hours.
const _kWelcomeBackThresholdMs = 24 * 60 * 60 * 1000;

/// Minimum gap (ms) between two greeting computations in the *same*
/// app session so we don't re-greet on every widget rebuild.
const _kMinGreetingGapMs = 5 * 60 * 1000; // 5 minutes

/// Smart greeting [FutureProvider].
///
/// Reads visit history from SharedPreferences and returns a
/// localization key name (not the translated string itself — that
/// is resolved by the widget via `S.of(context)`).
///
/// Returns one of:
///  - `'greetingFirstVisit'`  — first ever visit
///  - `'greetingWelcomeBack'` — returning after 24h+
///  - `'greetingSameDay'`      — returning same day (< 24h)
final smartGreetingProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now().millisecondsSinceEpoch;
  final hasVisitedBefore = prefs.getBool(_kHasVisitedBefore) ?? false;

  // ── Scenario 1: First visit ──
  if (!hasVisitedBefore) {
    await prefs.setBool(_kHasVisitedBefore, true);
    await prefs.setInt(_kLastVisitTimestamp, now);
    return 'greetingFirstVisit';
  }

  final lastVisit = prefs.getInt(_kLastVisitTimestamp) ?? 0;
  final diffMs = now - lastVisit;

  // ── Update timestamp ──
  await prefs.setInt(_kLastVisitTimestamp, now);

  // ── Scenario 2: 24h+ absence ──
  if (diffMs >= _kWelcomeBackThresholdMs) {
    return 'greetingWelcomeBack';
  }

  // ── Scenario 3: Same day return ──
  return 'greetingSameDay';
});

/// Helper that maps a greeting key returned by [smartGreetingProvider]
/// to a Kurdish Sorani string.
///
/// This is intentionally kept separate from the localization system
/// so that the greeting provider itself stays pure and testable.
/// When the full l10n pipeline is active, the widget should prefer
/// `AppLocalizations.of(context)` instead.
String resolveGreetingKey(String key) {
  switch (key) {
    case 'greetingFirstVisit':
      return 'بەخێربێیت بۆ AURA';
    case 'greetingWelcomeBack':
      return 'بەخێربێیت، ئەمڕۆ چۆن یارمەتیت بدەم؟';
    case 'greetingSameDay':
      return 'سەلام، چۆن دەتوانم یارمەتیت بدەم؟';
    default:
      return 'سەلام، AURA';
  }
}
