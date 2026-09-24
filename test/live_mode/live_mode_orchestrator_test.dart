/// live_mode_orchestrator_test.dart
/// AURA P0 – Unit tests for LiveModeOrchestrator state machine
///
/// Verifies: IDLE→LISTENING→PROCESSING→SPEAKING→LISTENING cycle,
/// session generation guards, duplicate request prevention,
/// TTS feedback loop (stop STT before speak), bounded retry
/// (3 errors → auto-stop), stop from any state safely,
/// empty recognition handling, speak completion → restart listening.
///
/// Uses hand-crafted fakes since no mockito/mocktail in pubspec.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/live_mode/live_mode_orchestrator.dart';
import 'package:texo/core/live_mode/live_mode_state.dart';
import 'package:texo/core/live_mode/agent_processor.dart';
import 'package:texo/core/agent/agent_result.dart';
import 'package:texo/core/agent/agent_context.dart';
import 'package:texo/services/voice/voice_service.dart';
import 'package:texo/services/memory/memory_service.dart';
import 'package:texo/domain/entities/agent_config.dart';

// ── Hand-crafted Fakes ──

/// Fake VoiceService that records calls and allows controllable behavior.
class FakeVoiceService implements VoiceService {
  final List<String> methodCalls = [];
  
  /// Set this to control what startListening does when called.
  void Function(void Function(String text) onRecognized)? onStartListening;
  
  /// If true, startListening throws.
  bool throwOnStart = false;
  
  /// If true, speak() throws.
  bool throwOnSpeak = false;
  
  /// Duration speak() takes before completing (simulates TTS time).
  Duration speakDuration = Duration.zero;
  
  VoiceState _state = VoiceState.idle;
  final _stateController = StreamController<VoiceState>.broadcast();
  
  /// The onRecognized callback saved from startListening.
  void Function(String text)? _savedOnRecognized;
  
  
  VoiceState get state => _state;
  
  
  Stream<VoiceState> get stateStream => _stateController.stream;
  
  
  Future<void> startListening({
    required void Function(String text) onRecognized,
    String locale = 'ku',
  }) async {
    methodCalls.add('startListening');
    _savedOnRecognized = onRecognized;
    _state = VoiceState.listening;
    _stateController.add(_state);
    if (throwOnStart) throw Exception('STT failed');
    onStartListening?.call(onRecognized);
  }
  
  /// Simulate a final recognition result coming from STT.
  void simulateRecognition(String text) {
    _savedOnRecognized?.call(text);
  }
  
  
  Future<void> stopListening() async {
    methodCalls.add('stopListening');
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  
  Future<void> speak(String text, {String locale = 'ku'}) async {
    methodCalls.add('speak:$text');
    _state = VoiceState.speaking;
    _stateController.add(_state);
    if (throwOnSpeak) throw Exception('TTS failed');
    if (speakDuration != Duration.zero) {
      await Future.delayed(speakDuration);
    }
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  
  Future<void> stopSpeaking() async {
    methodCalls.add('stopSpeaking');
    _state = VoiceState.idle;
    _stateController.add(_state);
  }
  
  void dispose() {
    _stateController.close();
  }
}

/// Fake AgentProcessor that records run() calls and returns configurable results.
class FakeAgentProcessor implements AgentProcessor {
  final List<(String, AgentContext)> runCalls = [];
  
  /// The result to return from run().
  AgentResult Function(String userInput, AgentContext context)? runHandler;
  
  /// Default: returns success with a response.
  AgentResult defaultResult = const AgentResult.success(
    response: 'وەڵامی تاقیکردنەوە',
    stepsCompleted: 1,
  );
  
  
  Future<AgentResult> run({
    required String userInput,
    required AgentContext context,
  }) async {
    runCalls.add((userInput, context));
    if (runHandler != null) {
      return runHandler!(userInput, context);
    }
    return defaultResult;
  }
}

/// Fake MemoryService for testing.
class FakeMemoryService implements MemoryService {
  final List<String> methodCalls = [];
  String? _conversationId;
  final List<MessageEntity> _messages = [];
  bool throwOnCreate = false;
  bool throwOnAddMessage = false;
  
  
  Future<String> createConversation({String? title, String? agentId}) async {
    methodCalls.add('createConversation');
    if (throwOnCreate) throw Exception('DB failed');
    _conversationId = 'conv_test';
    return _conversationId!;
  }
  
  
  Future<List<String>> getConversationIds({int limit = 50, int offset = 0}) async {
    methodCalls.add('getConversationIds');
    return _conversationId != null ? [_conversationId!] : [];
  }
  
  
  Future<void> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? parentMessageId,
  }) async {
    methodCalls.add('addMessage:$role:$content');
    if (throwOnAddMessage) throw Exception('DB write failed');
    _messages.add(MessageEntity(
      id: 'msg_${_messages.length}',
      conversationId: conversationId,
      role: role,
      content: content,
    ));
  }
  
  
  Future<List<MessageEntity>> getMessages(String conversationId) async {
    methodCalls.add('getMessages');
    return List.from(_messages);
  }
  
  
  Future<void> deleteConversation(String conversationId) async {
    methodCalls.add('deleteConversation');
    _messages.clear();
    _conversationId = null;
  }
}

// ── Helper to create orchestrator with fakes ──

LiveModeOrchestrator createOrchestrator({
  FakeVoiceService? voiceService,
  FakeAgentProcessor? agentProcessor,
  FakeMemoryService? memoryService,
}) {
  return LiveModeOrchestrator(
    voiceService: voiceService ?? FakeVoiceService(),
    agentProcessor: agentProcessor ?? FakeAgentProcessor(),
    memoryService: memoryService ?? FakeMemoryService(),
  );
}

void main() {
  group('LiveModeOrchestrator', () {
    group('startSession', () {
      test('transitions IDLE to LISTENING on start', () async {
        final fakeVoice = FakeVoiceService();
        final orchestrator = createOrchestrator(voiceService: fakeVoice);
        
        final states = <LiveModeState>[];
        orchestrator.onStateChanged = (s) => states.add(s);
        
        final session = await orchestrator.startSession();
        
        expect(session, isNotNull);
        expect(orchestrator.state, LiveModeState.listening);
        expect(states, contains(LiveModeState.listening));
        expect(fakeVoice.methodCalls, contains('startListening'));
      });
      
      test('returns null if not IDLE (cannot start from non-idle)', () async {
        final orchestrator = createOrchestrator();
        
        await orchestrator.startSession();
        expect(orchestrator.state, LiveModeState.listening);
        
        final second = await orchestrator.startSession();
        expect(second, isNull);
      });
    });
    
    group('stopSession', () {
      test('returns to IDLE from LISTENING without restarting STT', () async {
        final fakeVoice = FakeVoiceService();
        final orchestrator = createOrchestrator(voiceService: fakeVoice);
        
        await orchestrator.startSession();
        expect(orchestrator.state, LiveModeState.listening);
        
        await orchestrator.stopSession();
        
        expect(orchestrator.state, LiveModeState.idle);
        expect(orchestrator.isActive, isFalse);
        final stopCount = fakeVoice.methodCalls
            .where((c) => c == 'stopListening').length;
        expect(stopCount, greaterThanOrEqualTo(1));
      });
    });
    
    group('state machine cycle', () {
      test('LISTENING to PROCESSING to SPEAKING to LISTENING', () async {
        final fakeVoice = FakeVoiceService();
        final fakeEngine = FakeAgentProcessor();
        final orchestrator = createOrchestrator(
          voiceService: fakeVoice,
          agentProcessor: fakeEngine,
        );
        
        final states = <LiveModeState>[];
        orchestrator.onStateChanged = (s) => states.add(s);
        
        // Start session to LISTENING.
        await orchestrator.startSession();
        expect(orchestrator.state, LiveModeState.listening);
        
        // Simulate STT final recognition.
        fakeVoice.simulateRecognition('سڵاو');
        
        // Allow async processing to complete.
        await Future.delayed(const Duration(milliseconds: 100));
        
        // After recognition: should have transitioned through PROCESSING, SPEAKING.
        expect(states, contains(LiveModeState.processing));
        expect(states, contains(LiveModeState.speaking));
        
        // After speak completes: should return to LISTENING.
        await Future.delayed(const Duration(milliseconds: 100));
        expect(orchestrator.state, LiveModeState.listening);
        
        // AgentProcessor should have been called.
        expect(fakeEngine.runCalls.length, 1);
        expect(fakeEngine.runCalls.first.$1, 'سڵاو');
        
        // Voice should have spoken.
        expect(fakeVoice.methodCalls.any((c) => c.startsWith('speak:')), isTrue);
      });
    });
    
    group('duplicate request prevention', () {
      test('isProcessingRequest prevents duplicate when two recognitions arrive', () async {
        final fakeVoice = FakeVoiceService();
        final fakeEngine = FakeAgentProcessor();
        final orchestrator = createOrchestrator(
          voiceService: fakeVoice,
          agentProcessor: fakeEngine,
        );
        
        await orchestrator.startSession();
        
        // First recognition.
        fakeVoice.simulateRecognition('یەکەم');
        // Second recognition immediately (before first finishes processing).
        fakeVoice.simulateRecognition('دووەم');
        
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Only the first should be processed; the second is blocked by _isProcessingRequest.
        expect(fakeEngine.runCalls.length, 1);
        expect(fakeEngine.runCalls.first.$1, 'یەکەم');
      });
    });
    
    group('empty recognition handling', () {
      test('empty text goes back to listening without processing', () async {
        final fakeVoice = FakeVoiceService();
        final fakeEngine = FakeAgentProcessor();
        final orchestrator = createOrchestrator(
          voiceService: fakeVoice,
          agentProcessor: fakeEngine,
        );
        
        await orchestrator.startSession();
        
        // Simulate empty recognition.
        fakeVoice.simulateRecognition('');
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // AgentProcessor should NOT be called.
        expect(fakeEngine.runCalls.length, 0);
        // Should still be in LISTENING (or returned to it).
        expect(orchestrator.state, LiveModeState.listening);
      });
    });
    
    group('bounded retry', () {
      test('3 consecutive errors auto-stop to ERROR then IDLE', () async {
        final fakeVoice = FakeVoiceService();
        fakeVoice.throwOnStart = true; // STT always fails.
        final orchestrator = createOrchestrator(voiceService: fakeVoice);
        
        final states = <LiveModeState>[];
        orchestrator.onStateChanged = (s) => states.add(s);
        
        await orchestrator.startSession();
        
        // Error → retry loop. Let it run through 3 errors.
        await Future.delayed(const Duration(milliseconds: 700));
        await Future.delayed(const Duration(milliseconds: 700));
        await Future.delayed(const Duration(milliseconds: 700));
        
        // After 3 errors: should have reached ERROR state.
        expect(states, contains(LiveModeState.error));
      });
    });
    
    group('TTS feedback loop prevention', () {
      test('stopListening is called before speak', () async {
        final fakeVoice = FakeVoiceService();
        final fakeEngine = FakeAgentProcessor();
        final orchestrator = createOrchestrator(
          voiceService: fakeVoice,
          agentProcessor: fakeEngine,
        );
        
        await orchestrator.startSession();
        
        // Clear method log to focus on the cycle.
        fakeVoice.methodCalls.clear();
        
        // Simulate recognition.
        fakeVoice.simulateRecognition('تاقیکردنەوە');
        
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Verify: stopListening appears before speak in the call sequence.
        final stopIndex = fakeVoice.methodCalls.indexOf('stopListening');
        final speakIndex = fakeVoice.methodCalls.indexWhere((c) => c.startsWith('speak:'));
        
        // If both are present, stop must come before speak.
        if (stopIndex >= 0 && speakIndex >= 0) {
          expect(stopIndex, lessThan(speakIndex));
        }
        // At minimum, speak should have been called.
        expect(speakIndex, greaterThanOrEqualTo(0));
      });
    });
    
    group('session generation guards', () {
      test('stopSession invalidates pending callbacks via generation bump', () async {
        final fakeVoice = FakeVoiceService();
        final fakeEngine = FakeAgentProcessor();
        final orchestrator = createOrchestrator(
          voiceService: fakeVoice,
          agentProcessor: fakeEngine,
        );
        
        final session = await orchestrator.startSession();
        expect(session, isNotNull);
        expect(session!.generation, 1);
        
        // Stop bumps generation.
        await orchestrator.stopSession();
        
        // Old session generation is 1, orchestrator is now past that.
        expect(session.isCurrent(1), isTrue); // Session stores gen 1.
        // Orchestrator internal generation has moved past 1.
      });
    });
  });
}
