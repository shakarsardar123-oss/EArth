import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/audio/voice_activity_detector.dart';

void main() {
  group('VoiceActivityDetector', () {
    test('confirms speech onset only after startFrames', () {
      final vad = VoiceActivityDetector(
          energyThreshold: 0.1, startFrames: 3, hangoverFrames: 4);
      expect(vad.addFrame(0.5), VadTransition.none); // 1
      expect(vad.addFrame(0.5), VadTransition.none); // 2
      expect(vad.addFrame(0.5), VadTransition.speechStart); // 3
      expect(vad.isSpeaking, isTrue);
    });

    test('single loud spike does NOT trigger (barge-in false-positive guard)',
        () {
      final vad = VoiceActivityDetector(
          energyThreshold: 0.1, startFrames: 3, hangoverFrames: 4);
      expect(vad.addFrame(0.9), VadTransition.none);
      expect(vad.addFrame(0.0), VadTransition.none);
      expect(vad.addFrame(0.9), VadTransition.none);
      expect(vad.addFrame(0.0), VadTransition.none);
      expect(vad.isSpeaking, isFalse);
    });

    test('ends speech after hangoverFrames of silence', () {
      final vad = VoiceActivityDetector(
          energyThreshold: 0.1, startFrames: 2, hangoverFrames: 3);
      vad.addFrame(0.5);
      vad.addFrame(0.5); // now speaking
      expect(vad.isSpeaking, isTrue);
      expect(vad.addFrame(0.0), VadTransition.none); // 1 silent
      expect(vad.addFrame(0.0), VadTransition.none); // 2 silent
      expect(vad.addFrame(0.0), VadTransition.speechEnd); // 3 silent
      expect(vad.isSpeaking, isFalse);
    });

    test('rejects out-of-band ZCR (rumble / hiss) as non-speech', () {
      final vad = VoiceActivityDetector(
          energyThreshold: 0.1,
          zcrMin: 0.05,
          zcrMax: 0.6,
          startFrames: 2);
      // Loud but ZCR too low (DC rumble)
      expect(vad.addFrame(0.9, zcr: 0.0), VadTransition.none);
      expect(vad.addFrame(0.9, zcr: 0.0), VadTransition.none);
      // Loud but ZCR too high (hiss)
      expect(vad.addFrame(0.9, zcr: 0.95), VadTransition.none);
      expect(vad.isSpeaking, isFalse);
    });

    test('reset clears state', () {
      final vad = VoiceActivityDetector(startFrames: 1, energyThreshold: 0.1);
      vad.addFrame(0.5);
      expect(vad.isSpeaking, isTrue);
      vad.reset();
      expect(vad.isSpeaking, isFalse);
    });
  });
}
