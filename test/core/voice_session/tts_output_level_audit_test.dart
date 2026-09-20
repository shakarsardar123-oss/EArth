// Phase 5: TTS output-level source audit.
//
// flutter_tts (^4.0.2) exposes NO PCM / RMS amplitude — only word-boundary
// callbacks via `setProgressHandler`. So AURA's waveform is driven by a REAL
// speech-ACTIVITY envelope: peaks are triggered by genuine word events and
// then decay deterministically. These source-level audits lock that contract
// in place (no platform channels are needed to run them) and guard against a
// regression to a fabricated / Random()-based signal.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('$path not found');
  }
  return file.readAsStringSync();
}

void main() {
  group('Phase 5: TextToSpeechServiceImpl output-level path', () {
    late String src;

    setUpAll(() {
      src = _read('lib/core/voice/text_to_speech_impl.dart');
    });

    test('exposes an outputLevelStream backed by a broadcast controller', () {
      expect(src.contains('Stream<double> get outputLevelStream'), isTrue);
      expect(
        src.contains('StreamController<double>.broadcast()'),
        isTrue,
      );
    });

    test('level RISES are driven by real word-boundary callbacks', () {
      expect(src.contains('setProgressHandler('), isTrue,
          reason: 'Envelope must be triggered by genuine TTS word events');
    });

    test('decay is deterministic (Timer), never Random', () {
      expect(src.contains('Timer.periodic('), isTrue);
      expect(src.contains('Random('), isFalse,
          reason: 'The TTS level must NOT be a fabricated random signal');
      expect(src.contains('import \'dart:math\''), isFalse);
    });

    test('resources are released in dispose()', () {
      expect(src.contains('void dispose()'), isTrue);
      expect(src.contains('_levelDecayTimer?.cancel()'), isTrue);
    });
  });

  group('Phase 5: VoiceServiceImpl forwards the real TTS level', () {
    test('speakingLevelStream delegates to the TTS outputLevelStream', () {
      final src = _read('lib/core/voice/voice_service_impl.dart');
      expect(
        src.contains(
            'Stream<double> get speakingLevelStream => _textToSpeech.outputLevelStream'),
        isTrue,
      );
    });
  });

  group('Phase 5: coordinator + providers expose the speaking level', () {
    test('coordinator forwards VoiceService.speakingLevelStream', () {
      final src =
          _read('lib/core/voice_session/voice_session_coordinator.dart');
      expect(
        src.contains(
            'Stream<double> get speakingLevelStream => _voiceService.speakingLevelStream'),
        isTrue,
      );
    });

    test('a Riverpod provider surfaces the speaking level for the UI', () {
      final src =
          _read('lib/core/voice_session/voice_session_providers.dart');
      expect(src.contains('voiceAssistantSpeakingLevelProvider'), isTrue);
    });
  });
}
