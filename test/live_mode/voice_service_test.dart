/// voice_service_test.dart
/// AURA P0 – Unit tests for VoiceService abstract interface
///
/// Verifies: interface contract, method signatures,
/// TTS/STT lifecycle expectations.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:texo/services/voice/voice_service.dart';

/// Concrete test implementation of VoiceService.
class TestVoiceService implements VoiceService {
  VoiceState _state = VoiceState.idle;
  final _stateController = StreamController<VoiceState>.broadcast();
  String? _lastSpokenText;
  bool _stopSpeakingCalled = false;
  void Function(String)? _savedOnRecognized;
  
  @override
  VoiceState get state => _state;
  
  @override
  Stream<VoiceState> get stateStream => _stateController.stream;
  
  @override
  Future<void> speak(String text, {String locale = 'ku'}) async {
    _lastSpokenText = text;
    _state = VoiceState.speaking;
    _stateController.add(_state);
    // Simulate completion.
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  @override
  Future<void> stopSpeaking() async {
    _stopSpeakingCalled = true;
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  @override
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String locale = 'ku',
  }) async {
    _state = VoiceState.listening;
    _stateController.add(_state);
    _savedOnRecognized = onRecognized;
  }
  
  @override
  Future<void> stopListening() async {
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  // Test helpers
  String? get lastSpokenText => _lastSpokenText;
  bool get stopSpeakingCalled => _stopSpeakingCalled;
  
  void dispose() {
    _stateController.close();
  }
}

void main() {
  group('VoiceService interface', () {
    test('speak stores text for later retrieval', () async {
      final service = TestVoiceService();
      await service.speak('سڵاو جیهان');
      expect(service.lastSpokenText, 'سڵاو جیهان');
    });
    
    test('startListening/stopListening state transitions', () async {
      final service = TestVoiceService();
      expect(service.state, VoiceState.idle);
      
      await service.startListening(onRecognized: (_) {});
      expect(service.state, VoiceState.listening);
      
      await service.stopListening();
      expect(service.state, VoiceState.idle);
    });
    
    test('stopSpeaking marks flag and resets state', () async {
      final service = TestVoiceService();
      await service.speak('تاقیکردنەوە');
      await service.stopSpeaking();
      expect(service.stopSpeakingCalled, isTrue);
      expect(service.state, VoiceState.idle);
    });
    
    test('startListening accepts locale parameter', () async {
      final service = TestVoiceService();
      await service.startListening(
        onRecognized: (_) {},
        locale: 'ckb_IQ',
      );
      expect(service.state, VoiceState.listening);
    });
    
    test('VoiceState.isActive is true for active states', () {
      expect(VoiceState.listening.isActive, isTrue);
      expect(VoiceState.processing.isActive, isTrue);
      expect(VoiceState.speaking.isActive, isTrue);
      expect(VoiceState.idle.isActive, isFalse);
      expect(VoiceState.error.isActive, isFalse);
    });
  });
}
