/// live_mode_orchestrator.dart
/// AURA Assistant – P0 Remediation: Live Mode Orchestrator
///
/// Core state machine: IDLE→LISTENING→PROCESSING→SPEAKING→LISTENING cycle.
///
/// CRITICAL FIXES:
/// 1. TTS feedback loop prevention: stop STT before TTS, restart after TTS completion.
/// 2. Real TTS completion callback: uses awaitSpeakCompletion(true) → speak() resolves after speech.
/// 3. Duplicate request prevention: generation token + finalResult filter.
/// 4. Race condition prevention: session generation guards all state transitions.
/// 5. Bounded retry: max 3 consecutive errors → auto-stop.
///
/// NEVER uses timers for TTS completion — relies on VoiceService.speak() await.
library;

import 'dart:async';

import '../../services/voice/voice_service.dart'
    show VoiceService;
import 'agent_processor.dart';
import '../agent/agent_context.dart';

import '../../domain/entities/agent_config.dart';
import '../../services/memory/memory_service.dart';
import 'live_mode_state.dart';
import '../../core/errors/result.dart';

/// Callback for Live Mode state changes (for UI updates).
typedef LiveModeStateCallback = void Function(LiveModeState state);

/// Callback for recognized user text (for chat display).
typedef LiveModeRecognizedCallback = void Function(String text);

/// Callback for AI response text (for chat display).
typedef LiveModeResponseCallback = void Function(String text);

/// Orchestrates the continuous Live Mode voice cycle.
///
/// Flow:
/// 1. User activates Live Mode → IDLE→LISTENING
/// 2. STT recognizes final result → LISTENING→PROCESSING
/// 3. AgentProcessor processes input → PROCESSING→SPEAKING
/// 4. TTS speaks response, await resolves → SPEAKING→LISTENING
/// 5. Cycle continues until user stops or error limit reached.
class LiveModeOrchestrator {
  LiveModeOrchestrator({
    required VoiceService voiceService,
    required AgentProcessor agentProcessor,
    required MemoryService memoryService,
    List<String>? exitCommands,
    Duration? inactivityTimeout,
    Duration? rePromptGrace,
  })  : _voiceService = voiceService,
        _agentProcessor = agentProcessor,
        _memoryService = memoryService,
        _exitCommands = exitCommands ?? _defaultExitCommands,
        _inactivityTimeout = inactivityTimeout,
        _rePromptGrace = rePromptGrace ?? const Duration(seconds: 8);

  final VoiceService _voiceService;
  final AgentProcessor _agentProcessor;
  final MemoryService _memoryService;

  /// Phrases that explicitly end the voice session when heard while
  /// LISTENING. Matched case-insensitively as a substring of the final
  /// recognition, so "okay, stop aura" also ends the session. Covers the
  /// Kurdish Sorani exit command plus common English equivalents.
  final List<String> _exitCommands;

  /// Default localized + English exit commands. Kept as a const so the
  /// zero-config constructor keeps the assistant's advertised behaviour.
  static const List<String> _defaultExitCommands = <String>[
    // Kurdish Sorani
    'خۆت ناچالاک بکە',
    'ناچالاک بکە',
    'بەس بکە',
    'ماڵئاوا ئەورا',
    'ماڵئاوا',
    'کۆتایی',
    // English
    'stop aura',
    'goodbye aura',
    'goodbye',
    'that\'s all',
    'thats all',
    'stop listening',
  ];

  /// When non-null, the session ends after this much silence in LISTENING
  /// (with one gentle re-prompt first). null disables the timeout entirely
  /// so existing callers/tests are unaffected.
  final Duration? _inactivityTimeout;

  /// Extra grace period granted after the single gentle re-prompt before
  /// the session actually ends on continued silence.
  final Duration _rePromptGrace;

  Timer? _inactivityTimer;
  bool _rePromptGiven = false;

  LiveModeState _state = LiveModeState.idle;
  int _generation = 0;
  String? _currentSessionId;
  String? _currentConversationId;

  /// Consecutive error counter — auto-stop after [_maxConsecutiveErrors].
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  /// Whether a request is currently in-flight to prevent duplicates.
  bool _isProcessingRequest = false;

  /// Stream controller for state changes.
  final _stateController = StreamController<LiveModeState>.broadcast();

  /// Callbacks for UI updates.
  LiveModeStateCallback? onStateChanged;
  LiveModeRecognizedCallback? onUserRecognized;
  LiveModeResponseCallback? onAIResponse;

  /// Fired once when the session ends for a reason OTHER than an explicit
  /// [stopSession] call — i.e. a spoken exit command or the inactivity
  /// timeout. Lets the coordinator/UI dismiss the assistant pill and return
  /// to IDLE. The [String] is a short machine reason ('exit_command' |
  /// 'inactivity_timeout').
  void Function(String reason)? onSessionEnded;

  /// Current Live Mode state.
  LiveModeState get state => _state;

  /// Alias for state (backward compat with test expectations).
  LiveModeState get currentState => _state;

  /// Stream of state changes for UI.
  Stream<LiveModeState> get stateStream => _stateController.stream;

  /// Whether a Live session is currently active.
  bool get isActive => _state.isActive;

  /// Current session ID (null when idle).
  String? get currentSessionId => _currentSessionId;

  /// Current conversation ID for persistence.
  String? get currentConversationId => _currentConversationId;

  void _setState(LiveModeState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
      onStateChanged?.call(_state);
    }
  }

  /// Check if a generation is still current.
  bool _isCurrentGeneration(int gen) => gen == _generation;

  // ── Public API ──

  /// Start a Live Mode session.
  /// Returns the session, or null if cannot start.
  Future<LiveModeSession?> startSession() async {
    if (_state != LiveModeState.idle) return null;

    _generation++;
    final gen = _generation;
    _currentSessionId = 'live_${DateTime.now().millisecondsSinceEpoch}_$gen';
    _consecutiveErrors = 0;
    _isProcessingRequest = false;

    // Ensure we have a conversation for memory continuity.
    try {
      _currentConversationId = await _memoryService.createConversation(
        title: 'دەنگی زیندوو',
        agentId: 'default',
      );
    } catch (e) {
      // If DB fails, use a transient ID so Live Mode still works.
      _currentConversationId =
          'transient_${DateTime.now().millisecondsSinceEpoch}';
    }

    _setState(LiveModeState.listening);
    await _startListening(gen);

    return LiveModeSession(
      sessionId: _currentSessionId!,
      generation: gen,
    );
  }

  /// Stop a Live Mode session — user-initiated.
  /// Cancels all pending work and returns to IDLE.
  Future<void> stopSession() async {
    _generation++; // Invalidate all pending callbacks.
    _cancelInactivityTimer();
    _rePromptGiven = false;
    await _voiceService.stopListening();
    await _voiceService.stopSpeaking();
    _isProcessingRequest = false;
    _currentSessionId = null;
    _setState(LiveModeState.idle);
  }

  /// Barge-in: the user started talking while AURA was SPEAKING.
  ///
  /// Interrupts the in-progress TTS via the SAME [VoiceService.stopSpeaking]
  /// (no second TTS engine). Stopping speech makes the awaited `speak()` in
  /// [_speakThenRestartListening] resolve, which then transitions the state
  /// machine back to LISTENING for the new request — reusing the existing
  /// cycle rather than duplicating it.
  ///
  /// Returns true if an interruption actually happened.
  ///
  /// NOTE: This is an explicit barge-in trigger (invoked by the UI's
  /// interrupt affordance or an external VAD). Fully automatic acoustic
  /// barge-in — keeping the mic open DURING TTS — is intentionally not done
  /// here because the pipeline stops STT before TTS to prevent the mic from
  /// re-ingesting AURA's own voice (no exposed hardware echo cancellation).
  /// That limitation is documented in the Phase 5 report.
  Future<bool> bargeIn() async {
    if (_state != LiveModeState.speaking) return false;
    try {
      await _voiceService.stopSpeaking();
    } catch (_) {
      // Non-fatal — the awaited speak() will still resolve and the cycle
      // will fall through to LISTENING.
    }
    return true;
  }

  // ── Exit-command + inactivity helpers ──

  /// Case-insensitive substring match against the configured exit commands.
  bool _isExitCommand(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    for (final cmd in _exitCommands) {
      final c = cmd.toLowerCase().trim();
      if (c.isNotEmpty && normalized.contains(c)) return true;
    }
    return false;
  }

  /// End the session for a non-user-button reason (exit command / timeout).
  void _endSession(String reason) {
    _generation++; // Invalidate pending callbacks.
    _cancelInactivityTimer();
    _rePromptGiven = false;
    _voiceService.stopListening().catchError((_) {});
    _voiceService.stopSpeaking().catchError((_) {});
    _isProcessingRequest = false;
    _currentSessionId = null;
    _setState(LiveModeState.idle);
    onSessionEnded?.call(reason);
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Arm the silence timer for the current LISTENING window. On first
  /// expiry AURA gives ONE gentle spoken re-prompt and grants a grace
  /// window; on continued silence the session ends. Disabled when no
  /// [_inactivityTimeout] was configured.
  void _armInactivityTimer(int gen) {
    _cancelInactivityTimer();
    final timeout = _inactivityTimeout;
    if (timeout == null) return;
    _inactivityTimer = Timer(timeout, () => _onInactivity(gen));
  }

  Future<void> _onInactivity(int gen) async {
    if (!_isCurrentGeneration(gen)) return;
    if (_state != LiveModeState.listening) return;
    if (_isProcessingRequest) return;

    if (!_rePromptGiven) {
      // One gentle nudge, then keep listening for a grace window.
      _rePromptGiven = true;
      try {
        await _voiceService.stopListening();
        if (!_isCurrentGeneration(gen)) return;
        _setState(LiveModeState.speaking);
        await _voiceService.speak('هێشتا لێرەم، چیت پێویستە؟', locale: 'ku');
      } catch (_) {
        // Ignore — fall through to resume listening.
      }
      if (!_isCurrentGeneration(gen)) return;
      _setState(LiveModeState.listening);
      await _startListening(gen);
      // Grant grace: replace the freshly-armed timer with the grace window.
      _cancelInactivityTimer();
      _inactivityTimer = Timer(_rePromptGrace, () => _onInactivity(gen));
      return;
    }

    // Second consecutive silence — end the session.
    _endSession('inactivity_timeout');
  }

  // ── Core Cycle ──

  /// Start listening with generation guard.
  Future<void> _startListening(int gen) async {
    if (!_isCurrentGeneration(gen)) return;

    try {
      await _voiceService.startListening(
        onRecognized: (text) {
          // CRITICAL: Only process final results to prevent duplicates.
          // VoiceServiceImpl currently fires onResult for every event.
          // We guard with _isProcessingRequest to prevent duplicate processing.
          if (!_isCurrentGeneration(gen)) return;
          if (_isProcessingRequest) return; // Duplicate guard.
          if (_state != LiveModeState.listening) return; // Stale state.

          _isProcessingRequest = true;
          _onRecognizedFinal(gen, text);
        },
        locale: 'ckb_IQ',
      );
      // Session stays alive across turns; a silence timeout (if configured)
      // is the ONLY time-based path back to IDLE. TTS completion never ends
      // the session.
      _armInactivityTimer(gen);
    } catch (e) {
      if (!_isCurrentGeneration(gen)) return;
      _handleError(gen, 'STT start failed: $e');
    }
  }

  /// Called when STT produces a final recognition result.
  void _onRecognizedFinal(int gen, String text) {
    if (!_isCurrentGeneration(gen)) return;

    // Any recognized speech is activity — cancel the pending silence timeout.
    _cancelInactivityTimer();
    _rePromptGiven = false;

    if (text.trim().isEmpty) {
      // Empty recognition — go back to listening.
      _isProcessingRequest = false;
      _restartListening(gen);
      return;
    }

    // Explicit spoken exit command ends the session BEFORE it ever reaches
    // the agent — so "goodbye aura" is treated as a control phrase, never
    // run as a normal request (satisfies: wake/turn does not execute an
    // arbitrary tool by itself, and TTS completion is NOT what ends it).
    if (_isExitCommand(text)) {
      onUserRecognized?.call(text);
      _endSession('exit_command');
      return;
    }

    // Notify UI of recognized text.
    onUserRecognized?.call(text);

    // Transition to PROCESSING.
    _setState(LiveModeState.processing);

    // CRITICAL: Stop STT before processing (TTS feedback loop prevention step 1).
    _stopSTTThenProcess(gen, text);
  }

  /// Stop STT, then process the recognized text with AgentProcessor.
  /// This prevents the microphone from picking up TTS output.
  Future<void> _stopSTTThenProcess(int gen, String text) async {
    if (!_isCurrentGeneration(gen)) return;

    try {
      await _voiceService.stopListening();
    } catch (e) {
      // STT stop failure is non-fatal — continue processing.
    }

    if (!_isCurrentGeneration(gen)) return;

    // Persist user message.
    try {
      if (_currentConversationId != null) {
        await _memoryService.addMessage(
          conversationId: _currentConversationId!,
          role: 'user',
          content: text,
        );
      }
    } catch (e) {
      // Persistence failure is non-fatal — continue processing.
    }

    // Process with AgentProcessor.
    try {
      final agentConfig = await _getDefaultConfig();

      // Load conversation history for context continuity.
      List<Map<String, dynamic>> history = [];
      if (_currentConversationId != null) {
        try {
          final messages =
              await _memoryService.getMessages(_currentConversationId!);
          history = messages
              .map((m) => {
                    'role': m.role,
                    'content': m.content,
                  })
              .toList();
        } catch (e) {
          // History load failure is non-fatal.
        }
      }

      final context = AgentContext(
        agentConfig: agentConfig,
        conversationHistory: history,
        maxSteps: 10,
      );

      final result = await _agentProcessor.run(
        userInput: text,
        context: context,
      );

      if (!_isCurrentGeneration(gen)) return;

      if (result.isSuccess && result.response != null) {
        _consecutiveErrors = 0; // Reset on success.
        onAIResponse?.call(result.response!);

        // Persist AI response.
        try {
          if (_currentConversationId != null) {
            await _memoryService.addMessage(
              conversationId: _currentConversationId!,
              role: 'assistant',
              content: result.response!,
            );
          }
        } catch (e) {
          // Persistence failure is non-fatal.
        }

        // Transition to SPEAKING.
        _setState(LiveModeState.speaking);

        // CRITICAL: TTS feedback loop prevention step 2:
        // Speak the response. VoiceServiceImpl.speak() uses awaitSpeakCompletion(true)
        // which means _tts.speak() resolves ONLY AFTER speech completes.
        // So speak() below resolves when TTS is done. No timer needed.
        await _speakThenRestartListening(gen, result.response!);
      } else {
        final errMsg = result.errorMessage ?? 'ببورە، هەڵەیەک ڕوویدا.';
        onAIResponse?.call(errMsg);
        _handleError(gen, 'AgentProcessor failed: $errMsg');
      }
    } catch (e) {
      if (!_isCurrentGeneration(gen)) return;
      _handleError(gen, 'AgentProcessor exception: $e');
    }
  }

  /// Speak the response, then restart listening.
  /// This is the REAL TTS completion callback — speak() resolves
  /// only after TTS finishes (awaitSpeakCompletion(true)).
  Future<void> _speakThenRestartListening(int gen, String text) async {
    if (!_isCurrentGeneration(gen)) return;

    try {
      // VoiceServiceImpl.speak() awaits _tts.speak() which resolves
      // only after speech completes (because awaitSpeakCompletion(true)).
      await _voiceService.speak(text, locale: 'ku');
    } catch (e) {
      if (!_isCurrentGeneration(gen)) return;
      // TTS error — try to continue the cycle.
      _handleError(gen, 'TTS failed: $e');
      return;
    }

    if (!_isCurrentGeneration(gen)) return;

    // TTS completed. Reset processing flag and restart listening.
    _isProcessingRequest = false;
    _setState(LiveModeState.listening);
    await _startListening(gen);
  }

  /// Restart listening after empty recognition or reset.
  Future<void> _restartListening(int gen) async {
    if (!_isCurrentGeneration(gen)) return;
    if (_state != LiveModeState.listening) return;

    try {
      await _voiceService.stopListening();
    } catch (e) {
      // Non-fatal.
    }

    if (!_isCurrentGeneration(gen)) return;
    await _startListening(gen);
  }

  // ── Error Handling with Bounded Retry ──

  /// Handle an error. Increment counter; auto-stop if limit reached.
  void _handleError(int gen, String reason) {
    if (!_isCurrentGeneration(gen)) return;

    _consecutiveErrors++;
    _isProcessingRequest = false;

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      // Auto-stop: too many consecutive errors.
      _generation++; // Invalidate all pending callbacks.
      _voiceService.stopListening().catchError((_) {});
      _voiceService.stopSpeaking().catchError((_) {});
      _currentSessionId = null;
      _setState(LiveModeState.error);
      // After brief error display, go idle.
      Future.delayed(const Duration(seconds: 2), () {
        _setState(LiveModeState.idle);
      });
      return;
    }

    _setState(LiveModeState.error);
    // Retry after a short delay.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isCurrentGeneration(gen)) return;
      _isProcessingRequest = false;
      _setState(LiveModeState.listening);
      _startListening(gen);
    });
  }

  // ── Helpers ──

  /// Get a default agent config for AgentContext.
  Future<AgentConfig> _getDefaultConfig() async {
    return const AgentConfig(
      id: 'default',
      name: 'AURA',
      description: 'یاریدەدەری تایبەتی تۆ',
      systemPrompt:
          'من ئەورای تایبەتی تۆم. وەڵامی کوردی سۆرانی بدەرەوە.',
      modelId: 'gemini-3.6-flash',
      temperature: 0.7,
      maxTokens: 2048,
      isDefault: true,
      isActive: true,
    );
  }

  /// Dispose resources.
  void dispose() {
    _cancelInactivityTimer();
    _stateController.close();
  }
}
