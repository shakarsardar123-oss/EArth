/// stt_audio_input_repository_test.dart
/// AURA P0 – Unit tests for SttAudioInputRepository
///
/// Note: SttAudioInputRepository requires SpeechRecognitionServiceImpl (concrete),
/// which depends on platform. These tests verify the domain contract
/// and model interactions without platform-dependent code.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/continuous_listening/domain/repositories/audio_input_repository.dart';
import 'package:aura_assistant/features/continuous_listening/domain/models/segmentation_config.dart';
import 'package:aura_assistant/features/continuous_listening/domain/models/listening_session.dart';

void main() {
  group('AudioInputRepository contract', () {
    test('AudioInputResult.success is success', () {
      expect(AudioInputResult.success.isSuccess, isTrue);
      expect(AudioInputResult.success.isDenied, isFalse);
    });
    
    test('AudioInputResult denied variants are not success', () {
      expect(AudioInputResult.denied.isDenied, isTrue);
      expect(AudioInputResult.deniedPermission.isDenied, isTrue);
      expect(AudioInputResult.error.isDenied, isTrue);
      expect(AudioInputResult.unavailable.isDenied, isTrue);
    });
    
    test('SegmentationConfig defaults to Kurdish Sorani', () {
      const config = SegmentationConfig();
      expect(config.sttLanguage, 'ckb_IQ');
      expect(config.locale, 'ku');
      expect(config.mode, SegmentationMode.hybrid);
      expect(config.isUsable, isTrue);
    });
    
    test('SegmentationConfig.disabled is not usable', () {
      final config = SegmentationConfig.disabled();
      expect(config.enabled, isFalse);
      expect(config.isUsable, isFalse);
    });
    
    test('ListeningState fail-closed: only active is usable', () {
      expect(ListeningState.active.isActive, isTrue);
      expect(ListeningState.inactive.isActive, isFalse);
      expect(ListeningState.error.isActive, isFalse);
      expect(ListeningState.denied.isActive, isFalse);
      expect(ListeningState.unknown.isActive, isFalse);
    });
  });
}
