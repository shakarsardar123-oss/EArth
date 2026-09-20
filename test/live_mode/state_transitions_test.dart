/// state_transitions_test.dart
/// AURA P0 – State machine transition tests for Live Mode
///
/// Each test verifies ONE specific state transition in isolation.
/// No overlap with orchestrator_test.dart which tests multi-step cycles.
/// These are granular: IDLE→LISTENING, LISTENING→PROCESSING, etc.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/live_mode/live_mode_orchestrator.dart';
import 'package:aura_assistant/core/live_mode/live_mode_state.dart';
import 'package:aura_assistant/core/live_mode/agent_processor.dart';
import 'package:aura_assistant/core/agent/agent_result.dart';
import 'package:aura_assistant/core/agent/agent_context.dart';
import 'package:aura_assistant/services/voice/voice_service.dart';
import 'package:aura_assistant/services/memory/memory_service.dart';
import 'package:aura_assistant/domain/entities/agent_config.dart';

// ── Minimal Fakes (lighter than orchestrator_test's fakes) ──

class _TransitionVoiceService implements VoiceService {
  VoiceState _state = VoiceState.idle;
  final _stateController = StreamController<VoiceState>.broadcast();
  void Function(String text)? _savedOnRecognized;
  final List<String> calls = [];

  
  VoiceState get state => _state;
  
  Stream<VoiceState> get stateStream => _stateController.stream;

  
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String locale = 'ku',
  }) async {
    calls.add('start');
    _savedOnRecognized = onRecognized;
    _state = VoiceState.listening;
    _stateController.add(_state);
  }

  void simulateFinalResult(String text) => _savedOnRecognized?.call(text);

  
  Future<void> stopListening() async {
    calls.add('stop');
    _state = VoiceState.idle;
    _stateController.add(_state);
  }

  
  Future<void> speak(String text, {String locale = 'ku'}) async {
    calls.add('speak');
    _state = VoiceState.speaking;
    _stateController.add(_state);
    // Simulate TTS completion (speak resolves after speech).
    _state = VoiceState.idle;
    _stateController.add(_state);
  }

  
  Future<void> stopSpeaking() async {
    calls.add('stopSpeak');
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
}

class _TransitionAgentProcessor implements AgentProcessor {
  int runCount = 0;
  String? lastInput;

  
  Future<AgentResult> run({required String userInput, required AgentContext context}) async {
    runCount++;
    lastInput = userInput;
    return const AgentResult.success(response: 'وەڵام', stepsCompleted: 1);
  }
}

class _TransitionMemoryService implements MemoryService {
  
  Future<String> createConversation({String? title, String? agentId}) async => 'conv_1';
  
  Future<List<String>> getConversationIds({int limit = 50, int offset = 0}) async => [];
  
  Future<void> addMessage({required String conversationId, required String role, required String content, String? parentMessageId}) async {}
  
  Future<List<MessageEntity>> getMessages(String conversationId) async => [];
  
  Future<void> deleteConversation(String conversationId) async {}
}

void main() {
  group('IDLE → LISTENING', () {
    test('startSession transitions from IDLE to LISTENING', () async {
      final voice = _TransitionVoiceService();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: _TransitionAgentProcessor(),
        memoryService: _TransitionMemoryService(),
      );

      expect(orchestrator.state, LiveModeState.idle);
      expect(orchestrator.isActive, isFalse);

      final session = await orchestrator.startSession();

      expect(session, isNotNull);
      expect(orchestrator.state, LiveModeState.listening);
      expect(orchestrator.isActive, isTrue);
      expect(voice.calls, contains('start'));
    });

    test('startSession from non-IDLE returns null and does not change state', () async {
      final voice = _TransitionVoiceService();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: _TransitionAgentProcessor(),
        memoryService: _TransitionMemoryService(),
      );

      await orchestrator.startSession(); // Now LISTENING
      expect(orchestrator.state, LiveModeState.listening);

      final second = await orchestrator.startSession();
      expect(second, isNull);
      expect(orchestrator.state, LiveModeState.listening); // Unchanged
    });
  });

  group('LISTENING → PROCESSING', () {
    test('final recognition result triggers PROCESSING', () async {
      final voice = _TransitionVoiceService();
      final agent = _TransitionAgentProcessor();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: agent,
        memoryService: _TransitionMemoryService(),
      );

      final states = <LiveModeState>[];
      orchestrator.onStateChanged = (s) => states.add(s);

      await orchestrator.startSession();

      // Simulate STT final result
      voice.simulateFinalResult('سڵاو چۆنی');

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states, contains(LiveModeState.processing));
      expect(agent.runCount, 1);
      expect(agent.lastInput, 'سڵاو چۆنی');
    });
  });

  group('PROCESSING → SPEAKING', () {
    test('successful agent result transitions to SPEAKING', () async {
      final voice = _TransitionVoiceService();
      final agent = _TransitionAgentProcessor();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: agent,
        memoryService: _TransitionMemoryService(),
      );

      final states = <LiveModeState>[];
      orchestrator.onStateChanged = (s) => states.add(s);

      await orchestrator.startSession();
      voice.simulateFinalResult('تاقی');

      await Future.delayed(const Duration(milliseconds: 150));

      expect(states, contains(LiveModeState.speaking));
      expect(voice.calls.any((c) => c == 'speak'), isTrue);
    });
  });

  group('SPEAKING → LISTENING', () {
    test('after TTS completes, restarts listening', () async {
      final voice = _TransitionVoiceService();
      final agent = _TransitionAgentProcessor();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: agent,
        memoryService: _TransitionMemoryService(),
      );

      final states = <LiveModeState>[];
      orchestrator.onStateChanged = (s) => states.add(s);

      await orchestrator.startSession();
      voice.simulateFinalResult('تاقی');

      // Wait for full cycle: processing → speaking → listening
      await Future.delayed(const Duration(milliseconds: 300));

      // After speak() resolves, should return to LISTENING.
      expect(states.last, LiveModeState.listening);
      expect(orchestrator.state, LiveModeState.listening);
      // Should have called startListening again for the next cycle.
      final startCount = voice.calls.where((c) => c == 'start').length;
      expect(startCount, greaterThanOrEqualTo(2));
    });
  });

  group('User STOP from any state', () {
    test('STOP from LISTENING returns to IDLE', () async {
      final voice = _TransitionVoiceService();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: _TransitionAgentProcessor(),
        memoryService: _TransitionMemoryService(),
      );

      await orchestrator.startSession();
      expect(orchestrator.state, LiveModeState.listening);

      await orchestrator.stopSession();
      expect(orchestrator.state, LiveModeState.idle);
      expect(orchestrator.isActive, isFalse);
      // STT must be stopped, no new startListening call after stop.
      expect(voice.calls, contains('stop'));
    });

    test('STOP from PROCESSING returns to IDLE', () async {
      final voice = _TransitionVoiceService();
      final agent = _TransitionAgentProcessor();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: agent,
        memoryService: _TransitionMemoryService(),
      );

      await orchestrator.startSession();
      voice.simulateFinalResult('تاقی');

      // Let it reach PROCESSING but stop before TTS completes.
      await Future.delayed(const Duration(milliseconds: 30));

      await orchestrator.stopSession();
      expect(orchestrator.state, LiveModeState.idle);
      expect(orchestrator.isActive, isFalse);
    });

    test('STOP clears session ID', () async {
      final voice = _TransitionVoiceService();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: _TransitionAgentProcessor(),
        memoryService: _TransitionMemoryService(),
      );

      await orchestrator.startSession();
      expect(orchestrator.currentSessionId, isNotNull);

      await orchestrator.stopSession();
      expect(orchestrator.currentSessionId, isNull);
    });
  });

  group('Retry limit and duplicate prevention', () {
    test('agent failure increments error counter; 3 failures auto-stop', () async {
      final voice = _TransitionVoiceService();
      final agent = _FailingAgentProcessor();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: agent,
        memoryService: _TransitionMemoryService(),
      );

      final states = <LiveModeState>[];
      orchestrator.onStateChanged = (s) => states.add(s);

      await orchestrator.startSession();

      // Simulate 3 recognitions that each lead to agent failure.
      voice.simulateFinalResult('تاقی١');
      await Future.delayed(const Duration(milliseconds: 600));
      voice.simulateFinalResult('تاقی٢');
      await Future.delayed(const Duration(milliseconds: 600));
      voice.simulateFinalResult('تاقی٣');
      await Future.delayed(const Duration(milliseconds: 600));

      // After 3 consecutive errors: should reach ERROR state.
      expect(states, contains(LiveModeState.error));
    });

    test('duplicate recognition during processing is blocked', () async {
      final voice = _TransitionVoiceService();
      final agent = _TransitionAgentProcessor();
      final orchestrator = LiveModeOrchestrator(
        voiceService: voice,
        agentProcessor: agent,
        memoryService: _TransitionMemoryService(),
      );

      await orchestrator.startSession();

      // Send two rapid recognitions.
      voice.simulateFinalResult('یەکەم');
      voice.simulateFinalResult('دووەم'); // Should be blocked by _isProcessingRequest

      await Future.delayed(const Duration(milliseconds: 200));

      // Only the first was processed.
      expect(agent.runCount, 1);
      expect(agent.lastInput, 'یەکەم');
    });
  });
}

/// AgentProcessor that always fails — for retry limit testing.
class _FailingAgentProcessor implements AgentProcessor {
  
  Future<AgentResult> run({required String userInput, required AgentContext context}) async {
    return const AgentResult.failure(errorMessage: 'هەڵەی تاقیکردنەوە');
  }
}
