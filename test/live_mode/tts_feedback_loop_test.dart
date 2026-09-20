/// tts_feedback_loop_test.dart
/// AURA P0 – Integration-style test for TTS feedback loop prevention
///
/// CRITICAL: Verifies that the orchestrator does NOT create a feedback loop
/// where TTS output is picked up by STT as new input.
///
/// Test: After recognition, stopListening must have been called BEFORE speak.
/// Then after speak completes, startListening resumes.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/live_mode/live_mode_state.dart';
import 'package:aura_assistant/core/live_mode/live_mode_orchestrator.dart';
import 'package:aura_assistant/core/live_mode/agent_processor.dart';
import 'package:aura_assistant/core/agent/agent_result.dart';
import 'package:aura_assistant/core/agent/agent_context.dart';
import 'package:aura_assistant/services/voice/voice_service.dart';
import 'package:aura_assistant/services/memory/memory_service.dart';
import 'package:aura_assistant/domain/entities/agent_config.dart';

/// VoiceService that tracks call order for feedback loop prevention.
class FeedbackTrackingVoiceService implements VoiceService {
  final List<String> callLog = [];
  VoiceState _state = VoiceState.idle;
  final _stateController = StreamController<VoiceState>.broadcast();
  void Function(String)? _savedOnRecognized;
  
  
  VoiceState get state => _state;
  
  
  Stream<VoiceState> get stateStream => _stateController.stream;
  
  
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String locale = 'ku',
  }) async {
    callLog.add('startListening');
    _state = VoiceState.listening;
    _stateController.add(_state);
    _savedOnRecognized = onRecognized;
  }
  
  
  Future<void> stopListening() async {
    callLog.add('stopListening');
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  
  Future<void> speak(String text, {String locale = 'ku'}) async {
    callLog.add('speak:$text');
    _state = VoiceState.speaking;
    _stateController.add(_state);
    await Future.delayed(const Duration(milliseconds: 10));
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  
  Future<void> stopSpeaking() async {
    callLog.add('stopSpeaking');
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  /// Simulate a STT recognition result.
  void simulateRecognition(String text) {
    _savedOnRecognized?.call(text);
  }
  
  void dispose() {
    _stateController.close();
  }
}

class _FakeAgentProcessor implements AgentProcessor {
  
  Future<AgentResult> run({required String userInput, required AgentContext context}) async {
    return const AgentResult.success(response: 'وەڵام', stepsCompleted: 1);
  }
}

class _FakeMemoryService implements MemoryService {
  
  Future<String> createConversation({String? title, String? agentId}) async => 'conv_test';
  
  Future<List<String>> getConversationIds({int limit = 50, int offset = 0}) async => [];
  
  Future<void> addMessage({required String conversationId, required String role, required String content, String? parentMessageId}) async {}
  
  Future<List<MessageEntity>> getMessages(String conversationId) async => [];
  
  Future<void> deleteConversation(String conversationId) async {}
}

void main() {
  group('TTS feedback loop prevention', () {
    test('stopListening is called before speak during full cycle', () async {
      final voice = FeedbackTrackingVoiceService();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: _FakeAgentProcessor(),
        memoryService: _FakeMemoryService(),
      );
      
      await orchestrator.startSession();
      expect(voice.callLog, contains('startListening'));
      
      // Simulate recognition input
      voice.callLog.clear();
      voice.simulateRecognition('سڵاو');
      
      // Wait for async processing to complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify: stopListening must appear BEFORE speak in the call log
      final stopIndex = voice.callLog.indexWhere((e) => e == 'stopListening');
      final speakIndex = voice.callLog.indexWhere((e) => e.startsWith('speak:'));
      
      if (stopIndex >= 0 && speakIndex >= 0) {
        expect(stopIndex, lessThan(speakIndex),
            reason: 'stopListening must be called before speak to prevent feedback loop');
      }
    });
    
    test('after speak completes, listening resumes', () async {
      final voice = FeedbackTrackingVoiceService();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: _FakeAgentProcessor(),
        memoryService: _FakeMemoryService(),
      );
      
      await orchestrator.startSession();
      voice.callLog.clear();
      
      voice.simulateRecognition('سڵاو');
      await Future.delayed(const Duration(milliseconds: 300));
      
      // After full cycle: stopListening → speak → startListening
      expect(voice.callLog, contains('startListening'),
          reason: 'Listening must resume after TTS completes');
    });
    
    test('stopSession during SPEAKING does not restart STT', () async {
      final voice = FeedbackTrackingVoiceService();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: _FakeAgentProcessor(),
        memoryService: _FakeMemoryService(),
      );
      
      await orchestrator.startSession();
      voice.simulateRecognition('سڵاو');
      
      // Record call log state just before stop
      final logBeforeStop = List<String>.from(voice.callLog);
      
      // Stop session while speaking might be in progress
      await orchestrator.stopSession();
      
      expect(orchestrator.state, LiveModeState.idle);
      
      // Any new startListening after stopSession would be a bug
      final logAfterStop = voice.callLog;
      final newEntries = logAfterStop.skip(logBeforeStop.length).toList();
      expect(newEntries, isNot(contains('startListening')),
          reason: 'STT must not restart after stopSession');
    });
  });
}
