/// live_continuous_listening_service_test.dart
/// AURA P0 – Unit tests for LiveContinuousListeningService
///
/// Verifies: session lifecycle (start/stop), state mapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/live_mode/live_mode_state.dart';
import 'package:texo/core/live_mode/live_mode_orchestrator.dart';
import 'package:texo/core/live_mode/agent_processor.dart';
import 'package:texo/core/agent/agent_result.dart';
import 'package:texo/core/agent/agent_context.dart';
import 'package:texo/services/voice/voice_service.dart';
import 'package:texo/services/memory/memory_service.dart';
import 'package:texo/features/continuous_listening/infrastructure/live_continuous_listening_service.dart';
import 'package:texo/features/continuous_listening/domain/models/segmentation_config.dart';

class _FakeVoiceService implements VoiceService {
  
  VoiceState get state => VoiceState.idle;
  
  Stream<VoiceState> get stateStream => const Stream.empty();
  
  Future<void> speak(String text, {String locale = 'ku'}) async {}
  
  Future<void> stopSpeaking() async {}
  
  Future<void> startListening({required void Function(String text) onRecognized, String locale = 'ku'}) async {}
  
  Future<void> stopListening() async {}
}

class _FakeAgentProcessor implements AgentProcessor {
  
  Future<AgentResult> run({required String userInput, required AgentContext context}) async =>
      const AgentResult.success(response: 'چاو', stepsCompleted: 1);
}

class _FakeMemoryService implements MemoryService {
  
  Future<String> createConversation({String? title, String? agentId}) async => 'conv_test';
  
  Future<List<String>> getConversationIds({int limit = 50, int offset = 0}) async => [];
  
  Future<void> addMessage({required String conversationId, required String role, required String content, String? parentMessageId}) async {}
  
  Future<List<MessageEntity>> getMessages(String conversationId) async => [];
  
  Future<void> deleteConversation(String conversationId) async {}
}

void main() {
  group('LiveContinuousListeningService', () {
    test('startSession delegates to orchestrator and returns allowed', () async {
      final orchestrator = LiveModeOrchestrator(
        voiceService: _FakeVoiceService(),
        agentProcessor: _FakeAgentProcessor(),
        memoryService: _FakeMemoryService(),
      );
      final service = LiveContinuousListeningService(orchestrator: orchestrator);
      
      final verdict = await service.startSession(
        sessionId: 'test-1',
        config: const SegmentationConfig(),
      );
      expect(verdict.isAllowed, isTrue);
      expect(orchestrator.state, LiveModeState.listening);
    });
    
    test('stopSession stops orchestrator and returns inactive', () async {
      final orchestrator = LiveModeOrchestrator(
        voiceService: _FakeVoiceService(),
        agentProcessor: _FakeAgentProcessor(),
        memoryService: _FakeMemoryService(),
      );
      final service = LiveContinuousListeningService(orchestrator: orchestrator);
      
      await service.startSession(sessionId: 'test-1', config: const SegmentationConfig());
      final session = await service.stopSession('test-1');
      expect(session.state.isActive, isFalse);
      expect(orchestrator.state, LiveModeState.idle);
    });
    
    test('isAvailable returns true', () {
      final orchestrator = LiveModeOrchestrator(
        voiceService: _FakeVoiceService(),
        agentProcessor: _FakeAgentProcessor(),
        memoryService: _FakeMemoryService(),
      );
      final service = LiveContinuousListeningService(orchestrator: orchestrator);
      expect(service.isAvailable, isTrue);
    });
    
    test('startSession when already active returns denied', () async {
      final orchestrator = LiveModeOrchestrator(
        voiceService: _FakeVoiceService(),
        agentProcessor: _FakeAgentProcessor(),
        memoryService: _FakeMemoryService(),
      );
      final service = LiveContinuousListeningService(orchestrator: orchestrator);
      
      await service.startSession(sessionId: 'test-1', config: const SegmentationConfig());
      final second = await service.startSession(sessionId: 'test-2', config: const SegmentationConfig());
      expect(second.isDenied, isTrue);
    });
  });
}
