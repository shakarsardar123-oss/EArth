import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/voice/speech_recognition_impl.dart';
import '../../core/voice/text_to_speech_impl.dart';
import '../../core/voice/voice_service_impl.dart';

/// Provider for SpeechRecognitionServiceImpl.
final speechRecognitionProvider = Provider<SpeechRecognitionServiceImpl>((ref) {
  return SpeechRecognitionServiceImpl();
});

/// Provider for TextToSpeechServiceImpl.
final textToSpeechProvider = Provider<TextToSpeechServiceImpl>((ref) {
  return TextToSpeechServiceImpl();
});

/// Provider for VoiceServiceImpl.
final voiceServiceImplProvider = Provider<VoiceServiceImpl>((ref) {
  return VoiceServiceImpl(
    speechRecognition: ref.watch(speechRecognitionProvider),
    textToSpeech: ref.watch(textToSpeechProvider),
  );
});
