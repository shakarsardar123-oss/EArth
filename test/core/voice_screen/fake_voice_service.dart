/// Hand-written fake [VoiceService] for voice-screen engine tests.
library;

import 'dart:async';

import 'package:aura_assistant/services/voice/voice_service.dart';

/// Configuration for [FakeVoiceService].
class FakeVoiceConfig {
  /// Texts that will be auto-delivered via [onRecognized] after
  /// [startListening] is called. Each entry is delivered sequentially.
  final List<String> recognizedTexts;

  /// If true, [startListening] throws an unexpected exception.
  final bool shouldThrow;

  /// Delay before delivering recognized texts.
  final Duration delay;

  /// If non-null, [startListening] returns a failure-like state transition
  /// (sets VoiceState to error).
  final VoiceState? failureState;

  const FakeVoiceConfig({
    this.recognizedTexts = const [],
    this.shouldThrow = false,
    this.delay = Duration.zero,
    this.failureState,
  });
}

/// A fake [VoiceService] with configurable behaviour.
///
/// - Call [configure] before each test to set up expected outcomes.
/// - Tracks call counts and last arguments for assertions.
/// - Broadcasts state changes via [stateStream].
/// - Supports cancellation via [_cancelled] flag.
class FakeVoiceService implements VoiceService {
  FakeVoiceConfig _config = const FakeVoiceConfig();
  VoiceState _state = VoiceState.idle;
  final _stateController = StreamController<VoiceState>.broadcast();
  bool _cancelled = false;

  /// The last [onRecognized] callback stored by [startListening].
  /// Tests can invoke this manually to simulate recognition.
  void Function(String text)? lastOnRecognized;

  /// Call counts for verification.
  int startListeningCallCount = 0;
  int stopListeningCallCount = 0;
  int speakCallCount = 0;
  int stopSpeakingCallCount = 0;

  /// Last arguments for verification.
  String? lastLocale;
  String? lastSpokenText;

  /// Configure the fake's behaviour.
  void configure(FakeVoiceConfig config) {
    _config = config;
  }

  /// Whether the fake was cancelled.
  bool get wasCancelled => _cancelled;

  @override
  VoiceState get state => _state;

  @override
  Stream<VoiceState> get stateStream => _stateController.stream;

  @override
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String locale = 'ku',
  }) async {
    startListeningCallCount++;
    lastLocale = locale;
    lastOnRecognized = onRecognized;
    _cancelled = false;

    _setState(VoiceState.listening);

    if (_config.failureState != null) {
      _setState(_config.failureState!);
      return;
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake voice service');
    }

    // Auto-deliver recognized texts after delay.
    if (_config.recognizedTexts.isNotEmpty) {
      if (_config.delay > Duration.zero) {
        await Future.delayed(_config.delay);
      }
      for (final text in _config.recognizedTexts) {
        if (_cancelled) break;
        onRecognized(text);
      }
    }
  }

  @override
  Future<void> stopListening() async {
    stopListeningCallCount++;
    _cancelled = true;
    _setState(VoiceState.idle);
  }

  @override
  Future<void> speak(String text, {String locale = 'ku'}) async {
    speakCallCount++;
    lastSpokenText = text;
    lastLocale = locale;
    _setState(VoiceState.speaking);
  }

  @override
  Future<void> stopSpeaking() async {
    stopSpeakingCallCount++;
    _setState(VoiceState.idle);
  }

  /// Close the state stream controller (call in tearDown).
  Future<void> dispose() async {
    await _stateController.close();
  }

  void _setState(VoiceState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
