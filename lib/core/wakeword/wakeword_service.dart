import 'dart:async';

import 'package:meta/meta.dart';

import '../voice/voice_service_impl.dart';

/// Service for STT-keyword-based wake word detection (the documented
/// FALLBACK path used when the native [AcousticWakeWordEngine] model asset
/// is unavailable). Listens to speech-recognition results and fires a
/// callback when any configured wake phrase is spotted.
///
/// PRIMARY WAKE PHRASE: "Hey AURA" (English). The Kurdish/Sorani phrase
/// 'ئەورا' is also matched so a Sorani recognizer still wakes.
///
/// LANGUAGE / LOCALE CONSTRAINT (honest):
///   `speech_to_text` transcribes in ONE locale per session. The recognizer
///   locale therefore decides which language can actually be transcribed —
///   the UI language is a SEPARATE concern. To recognise "Hey AURA" without
///   forcing every user onto a Kurdish recognizer, [locale] now defaults to
///   `null` (the device's system speech locale) instead of the old hardcoded
///   'ckb_IQ'. An English-speech device will transcribe "hey texo"; a Sorani
///   device will transcribe 'ئەورا'. Guaranteed English-anywhere recognition
///   requires the native KWS model path (see [AcousticWakeWordEngine]); this
///   STT fallback does its best with the device recognizer.
///
/// P4 FIXES (retained):
/// 1. Auto-restarts listening after STT timeout (speech_to_text stops
///    after ~10-15s of silence; this service detects that and restarts).
/// 2. Removed false-match strings ('hamaumin', 'ھامامین', 'حامامین')
///    that were leftover test strings causing false triggers.
/// 3. Added keyword spotter interface (abstract KwsService) for future
///    native KWS model integration (e.g., Porcupine, Snowboy).
/// 4. Documented that true always-on wake word requires a native KWS
///    model + foreground service (not currently implemented).
class WakeWordService {
  WakeWordService({
    required VoiceServiceImpl voiceService,
    String wakeWord = 'ئەورا',
    List<String>? wakePhrases,
    String? locale,
  })  : _voiceService = voiceService,
        _wakeWord = wakeWord,
        _locale = locale,
        // Normalize the configured phrases once. Defaults cover the English
        // primary phrase (+ common recognizer variants) and the Sorani
        // phrase. "aura" alone is deliberately EXCLUDED to avoid false
        // triggers on unrelated speech containing the word.
        _normalizedPhrases = _dedupeNormalized(
          (wakePhrases ?? _defaultWakePhrases(wakeWord))
              .map(_normalize)
              .where((p) => p.isNotEmpty),
        );

  final VoiceServiceImpl _voiceService;
  final String _wakeWord;
  final String? _locale;
  final List<String> _normalizedPhrases;

  /// Default wake phrases: English primary + reasonable variants, plus the
  /// configured Sorani phrase. Kept narrow to avoid accidental triggers.
  static List<String> _defaultWakePhrases(String kurdishWakeWord) => <String>[
        'hey texo',
        'hey, aura',
        'hey ora',
        'hey aurora',
        'hi aura',
        kurdishWakeWord,
        'هێ ئەورا',
      ];

  bool _isListening = false;
  StreamSubscription<String>? _subscription;
  StreamSubscription<VoiceState>? _stateSubscription;
  void Function()? _onWakeWordDetected;
  Timer? _timeoutGuard;

  /// The primary (Kurdish) wake word string (default: ئەورا).
  String get wakeWord => _wakeWord;

  /// The normalized phrase set actually used for matching (for tests/debug).
  List<String> get wakePhrases => List.unmodifiable(_normalizedPhrases);

  /// Whether the service is actively listening for the wake word.
  bool get isListening => _isListening;

  /// Start listening for the wake word.
  /// When detected, [onWakeWordDetected] is called.
  Future<void> startListening({void Function()? onWakeWordDetected}) async {
    if (_isListening) return;

    _onWakeWordDetected = onWakeWordDetected;
    _isListening = true;

    await _startSttSession();

    // P4 FIX: Watch voice state to detect STT timeout (idle after listening)
    _stateSubscription = _voiceService.stateStream.listen((state) {
      if (!_isListening) return;
      // If STT auto-stopped (timed out on silence), voice goes idle
      if (state == VoiceState.idle || state == VoiceState.error) {
        _scheduleRestart();
      }
    });

    // P4 FIX: Periodic timeout guard in case state stream misses the stop
    _resetTimeoutGuard();
  }

  /// Stop listening for the wake word.
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    _timeoutGuard?.cancel();
    _timeoutGuard = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _subscription?.cancel();
    _subscription = null;
    _onWakeWordDetected = null;
    await _voiceService.stopListening();
  }

  Future<void> _startSttSession() async {
    try {
      await _voiceService.startListening(
        onRecognized: (text) {
          _checkForWakeWord(text);
        },
        // null → device system speech locale (see class doc: lets an
        // English-speech device transcribe "Hey AURA", a Sorani device
        // transcribe the Kurdish phrase). Overridable via constructor.
        locale: _locale,
      );

      // Subscribe to result stream as well
      _subscription = _voiceService.resultStream?.listen((text) {
        _checkForWakeWord(text);
      });
    } catch (e) {
      // STT init failed — schedule restart
      _scheduleRestart();
    }
  }

  /// P4 FIX: Schedule a restart of STT after a brief delay.
  /// This handles the speech_to_text timeout (~10-15s silence).
  void _scheduleRestart() {
    if (!_isListening) return;
    _timeoutGuard?.cancel();
    _timeoutGuard = Timer(const Duration(milliseconds: 800), () async {
      if (!_isListening) return;
      await _voiceService.stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isListening) {
        await _startSttSession();
        _resetTimeoutGuard();
      }
    });
  }

  /// P4 FIX: Reset the periodic timeout guard.
  /// If no state change is detected within 15 seconds, force a restart.
  void _resetTimeoutGuard() {
    _timeoutGuard?.cancel();
    _timeoutGuard = Timer(const Duration(seconds: 15), () {
      if (!_isListening) return;
      _scheduleRestart();
    });
  }

  void _checkForWakeWord(String text) {
    if (!_isListening) return;

    final normalized = _normalize(text);

    // Match against ANY configured, normalized wake phrase. This replaces the
    // old single-string raw contains() (which only matched the Kurdish word
    // and could never match "Hey AURA"). Normalization lowercases, strips
    // punctuation and collapses whitespace so "Hey, AURA!" == "hey texo".
    if (normalized.isNotEmpty &&
        _normalizedPhrases.any((p) => normalized.contains(p))) {
      _onWakeWordDetected?.call();
    }

    // Reset timeout guard on any speech activity (STT is still alive)
    _resetTimeoutGuard();
  }

  /// Normalize recognized text / wake phrases for robust matching:
  /// lowercase → replace punctuation with spaces → collapse whitespace → trim.
  /// Kept Unicode-friendly so the Kurdish phrase is preserved intact.
  static String _normalize(String input) {
    final lowered = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      final ch = String.fromCharCode(rune);
      // Treat ASCII punctuation and separators as spaces; keep letters
      // (including non-ASCII/Arabic-script) and digits.
      final isAsciiLetter = (rune >= 0x61 && rune <= 0x7a);
      final isDigit = (rune >= 0x30 && rune <= 0x39);
      final isNonAscii = rune > 0x7f;
      if (isAsciiLetter || isDigit || isNonAscii) {
        buffer.write(ch);
      } else {
        buffer.write(' ');
      }
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _dedupeNormalized(Iterable<String> phrases) {
    final seen = <String>{};
    final out = <String>[];
    for (final p in phrases) {
      if (seen.add(p)) out.add(p);
    }
    return out;
  }

  /// Test-only mirror of the exact production detection predicate used by
  /// [_checkForWakeWord]: normalize [text], then return true iff any of the
  /// [normalizedPhrases] is a substring of the normalized text. Kept in sync
  /// with the real matcher so unit tests exercise the same logic without a
  /// live [VoiceServiceImpl] / speech plugin.
  @visibleForTesting
  static bool matchesForTest(String text, List<String> normalizedPhrases) {
    final normalized = _normalize(text);
    return normalized.isNotEmpty &&
        normalizedPhrases.any((p) => normalized.contains(p));
  }

  /// Test-only accessor for the normalizer.
  @visibleForTesting
  static String normalizeForTest(String input) => _normalize(input);

  /// Dispose resources.
  void dispose() {
    stopListening();
  }
}

/// P4: Abstract interface for a native Keyword Spotting (KWS) service.
///
/// A real always-on wake word requires a native KWS model (e.g.,
/// Porcupine, Snowboy, or a custom TFLite model) running inside
/// a foreground service. This interface is provided so that a
/// future native implementation can be plugged in without changing
/// the WakeWordService architecture.
///
/// Current implementation uses STT-based detection which:
/// - Requires the app to be in the foreground
/// - Is battery-intensive (full speech recognition running continuously)
/// - May have false positives on similar-sounding words
/// - Stops after ~10-15s silence (auto-restart added as mitigation)
abstract class KwsService {
  /// Initialize the keyword spotting model.
  Future<bool> initialize();

  /// Start listening for the keyword.
  /// Calls [onKeywordDetected] when the wake word is spotted.
  Future<void> start({void Function()? onKeywordDetected});

  /// Stop listening for the keyword.
  Future<void> stop();

  /// Release model resources.
  void dispose();
}