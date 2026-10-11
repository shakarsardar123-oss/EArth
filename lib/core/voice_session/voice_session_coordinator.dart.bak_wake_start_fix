/// voice_session_coordinator.dart
/// AURA Assistant – Phase 5: Voice Assistant Session Coordinator
///
/// Ties together the EXISTING pieces into one "personal assistant" session
/// without duplicating any of them:
///
///   WakeWordService (core/wakeword)      → wake detection
///   LiveModeOrchestrator (core/live_mode) → the real IDLE→LISTENING→
///                                           PROCESSING→SPEAKING→LISTENING
///                                           loop (same Agent/memory/tools)
///   VoiceServiceImpl (core/voice)         → the single shared STT/TTS + the
///                                           real microphone sound-level
///                                           stream used by the pill waveform
///
/// This class adds ONLY the coordination glue the individual pieces lack:
///   • a WAKING phase between "wake heard" and "listening",
///   • arming/disarming wake detection around a live session (single mic),
///   • re-arming wake detection after the session ends,
///   • a unified [VoiceAssistantPhase] + sound level for the UI/pill.
///
/// It deliberately does NOT create a second orchestrator, TTS, STT, overlay,
/// agent, or conversation engine (see Phase 5 rule 17).
///
/// WAKE-WORD ARCHITECTURE (honest):
///   PRIMARY  : AcousticWakeWordEngine — a REAL on-device acoustic keyword
///              spotter. On Android it decodes the shared microphone PCM with
///              a bundled Vosk (Kaldi) acoustic model under a grammar
///              constrained to ["hey aura", "[unk]"], gating on the model's
///              own per-word confidence. This is genuine acoustic inference,
///              NOT a speech-to-text transcript search.
///   FALLBACK : the existing STT-keyword WakeWordService — used ONLY when the
///              acoustic engine is unavailable (no model asset / unsupported
///              platform). Never both at once (single mic).
///
/// This coordinator prefers the acoustic engine and only falls back to STT; it
/// never fabricates a detection. NOTE: wake listening is currently scoped to
/// while the app/session has the engine armed (IDLE). A dedicated background
/// foreground-microphone service for truly always-on/screen-off KWS is not
/// wired here — see AURA_REAL_WAKE_WORD_REPORT.md for that boundary.
library;

import 'dart:async';

import '../wakeword/wakeword_service.dart';
import '../voice/voice_service_impl.dart';
import '../live_mode/live_mode_orchestrator.dart';
import '../live_mode/live_mode_state.dart';
import '../audio/acoustic_wake_word_engine.dart';
import '../audio/barge_in_controller.dart';
import '../audio/output_level_monitor.dart';

/// User-facing phase of the whole voice-assistant session.
///
/// This is a superset of [LiveModeState] with an explicit [waking] phase
/// (the brief window after the wake word fires but before the mic is fully
/// re-tasked for command capture). Kept separate so we never mutate the
/// existing exhaustive [LiveModeState] enum.
enum VoiceAssistantPhase {
  /// Not in a session. Wake detection may still be armed underneath.
  idle,

  /// Wake word just detected; pill is appearing and mic is switching over.
  waking,

  /// Microphone open, capturing the user's request.
  listening,

  /// Request handed to the Agent (thinking / running tools).
  thinking,

  /// AURA is speaking the response via TTS.
  speaking,

  /// Recoverable error surfaced to the user before returning to a safe state.
  error;

  bool get isActive =>
      this == waking ||
      this == listening ||
      this == thinking ||
      this == speaking;

  /// Kurdish Sorani status label for the pill.
  String get statusText => switch (this) {
        idle => 'ئامادەیە',
        waking => 'تێکسۆ...',
        listening => 'گوێگرتن...',
        thinking => 'بیرکردنەوە...',
        speaking => 'قسەکردن...',
        error => 'هەڵە',
      };
}

/// Coordinates wake detection + the live voice session into one experience.
class VoiceSessionCoordinator {
  VoiceSessionCoordinator({
    required WakeWordService wakeWordService,
    required VoiceServiceImpl voiceService,
    required LiveModeOrchestrator orchestrator,
    bool wakeWordEnabled = true,
    // ── Final Voice Phase (all optional/additive) ──
    // When supplied, these upgrade the session to the real audio pipeline:
    //  • [wakeEngine]        genuine acoustic KWS (else STT keyword fallback)
    //  • [bargeInController] automatic acoustic barge-in during SPEAKING
    //  • [outputLevelMonitor] real AURA output RMS (else TTS word envelope)
    // All default to null so existing callers/tests are byte-for-byte
    // unaffected.
    AcousticWakeWordEngine? wakeEngine,
    BargeInController? bargeInController,
    OutputLevelMonitor? outputLevelMonitor,
  })  : _wakeWord = wakeWordService,
        _voiceService = voiceService,
        _orchestrator = orchestrator,
        _wakeWordEnabled = wakeWordEnabled,
        _wakeEngine = wakeEngine,
        _bargeIn = bargeInController,
        _outputMonitor = outputLevelMonitor {
    // Bridge the orchestrator's inner state into our unified phase via its
    // broadcast stateStream — NOT by hijacking onStateChanged, which the
    // existing live_mode_providers already uses for the Live Mode UI. This
    // way both consumers coexist without duplication.
    _stateSub = _orchestrator.stateStream.listen(_onOrchestratorState);
    // Re-arm wake detection when the session ends by voice/timeout. This
    // callback is Phase-5-only and not used elsewhere, so setting it is safe.
    _orchestrator.onSessionEnded = (_) => _onSessionEnded();
    // Automatic acoustic barge-in: a confirmed post-AEC speech onset while
    // AURA is SPEAKING interrupts TTS via the SAME orchestrator.bargeIn()
    // (no second TTS/mic). Only wired when a controller was supplied.
    _bargeIn?.onBargeIn = () {
      _orchestrator.bargeIn();
    };
  }

  final WakeWordService _wakeWord;
  final VoiceServiceImpl _voiceService;
  final LiveModeOrchestrator _orchestrator;

  // ── Final Voice Phase optional collaborators ──
  final AcousticWakeWordEngine? _wakeEngine;
  final BargeInController? _bargeIn;
  final OutputLevelMonitor? _outputMonitor;
  StreamSubscription<WakeEvent>? _wakeEngineSub;
  bool _usingAcousticWake = false;

  bool _wakeWordEnabled;
  bool _wakeArmed = false;
  bool _disposed = false;
  StreamSubscription<LiveModeState>? _stateSub;

  VoiceAssistantPhase _phase = VoiceAssistantPhase.idle;
  final _phaseController = StreamController<VoiceAssistantPhase>.broadcast();

  // ── Public surface ──

  VoiceAssistantPhase get phase => _phase;

  Stream<VoiceAssistantPhase> get phaseStream => _phaseController.stream;

  /// Real microphone amplitude stream (input path) for the pill waveform.
  Stream<double> get soundLevelStream => _voiceService.soundLevelStream;

  /// Real TTS output-activity stream (0..1, output path) for the pill
  /// waveform's SPEAKING reactivity. Peaks are driven by genuine flutter_tts
  /// word-boundary progress events (words actually being spoken); it is NOT
  /// a random/synthetic signal. See VoiceServiceImpl.speakingLevelStream for
  /// the platform-limitation note (no PCM/RMS amplitude available).
  Stream<double> get speakingLevelStream => _voiceService.speakingLevelStream;

  /// Preferred SPEAKING waveform source. When a real [OutputLevelMonitor] was
  /// supplied AND it is active (Android Visualizer RMS on the output mix),
  /// this returns the GENUINE acoustic output level of AURA's own voice.
  /// Otherwise it falls back to the flutter_tts word-activity envelope
  /// ([speakingLevelStream]) — which is real speech-activity data, not a
  /// fabricated animation. Never returns synthetic values.
  Stream<double> get outputLevelStream {
    final m = _outputMonitor;
    if (m != null && m.status == OutputLevelStatus.active) {
      return m.levelStream;
    }
    return _voiceService.speakingLevelStream;
  }

  /// Whether a genuine acoustic output level is currently available.
  bool get hasRealOutputLevel {
    final m = _outputMonitor;
    return m != null && m.status == OutputLevelStatus.active;
  }

  bool get isSessionActive => _orchestrator.isActive;

  bool get wakeWordEnabled => _wakeWordEnabled;

  bool get isWakeArmed => _wakeArmed;

  /// Optional hooks so the UI can mirror recognized/response text without
  /// reaching into the orchestrator directly.
  set onUserRecognized(void Function(String text)? cb) =>
      _orchestrator.onUserRecognized = cb;
  set onAIResponse(void Function(String text)? cb) =>
      _orchestrator.onAIResponse = cb;

  void _setPhase(VoiceAssistantPhase p) {
    if (_disposed || _phase == p) return;
    // Leaving SPEAKING: disarm barge-in so the mic is released and the VAD
    // does not run during LISTENING (where normal STT owns the mic).
    if (_phase == VoiceAssistantPhase.speaking &&
        p != VoiceAssistantPhase.speaking) {
      _bargeIn?.disarm();
    }
    _phase = p;
    _phaseController.add(p);
  }

  // ── Wake detection lifecycle ──

  /// Arm wake-word detection (idle background listening for "Hey AURA").
  /// No-op when the wake word is disabled in settings or a session is
  /// already active.
  Future<void> armWakeWord() async {
    if (_disposed || !_wakeWordEnabled) return;
    if (_wakeArmed || _orchestrator.isActive) return;
    _wakeArmed = true;

    // Prefer the genuine acoustic KWS engine when it is available. It runs a
    // small always-on model instead of full STT. Only when it is unavailable
    // (no model asset / unsupported platform) do we fall back to the existing
    // STT keyword WakeWordService — never both at once (single mic).
    final engine = _wakeEngine;
    if (engine != null) {
      final status = engine.status == WakeEngineStatus.uninitialized
          ? await engine.initialize()
          : engine.status;
      if (status == WakeEngineStatus.listening) {
        _usingAcousticWake = true;
        _wakeEngineSub ??= engine.wakeStream.listen((_) {
          _onWakeWordDetected();
        });
        await engine.start();
        return;
      }
    }

    _usingAcousticWake = false;
    await _wakeWord.startListening(onWakeWordDetected: _onWakeWordDetected);
  }

  /// Disarm wake-word detection.
  Future<void> disarmWakeWord() async {
    if (!_wakeArmed) return;
    _wakeArmed = false;
    if (_usingAcousticWake) {
      await _wakeEngine?.stop();
    } else {
      await _wakeWord.stopListening();
    }
  }

  /// Enable/disable the wake word at runtime (settings toggle). When
  /// disabled, any active wake listening is stopped; the user can still
  /// start a session manually via [startManual].
  Future<void> setWakeWordEnabled(bool enabled) async {
    _wakeWordEnabled = enabled;
    if (!enabled) {
      await disarmWakeWord();
    } else if (!_orchestrator.isActive) {
      await armWakeWord();
    }
  }

  // ── Session entry points ──

  /// Called by the wake-word engine when "Hey AURA" is spotted.
  Future<void> _onWakeWordDetected() async {
    // The wake service stops its own STT to free the single mic; mark
    // disarmed so we don't double-stop, then open the session.
    _wakeArmed = false;
    await _beginSession();
  }

  /// Manually open a session (e.g. tapping the assistant button, or an
  /// incoming Android ASSIST invocation). Same session as wake word.
  Future<LiveModeSession?> startManual() async {
    await disarmWakeWord();
    return _beginSession();
  }

  Future<LiveModeSession?> _beginSession() async {
    if (_disposed) return null;
    // Ensure the wake STT has fully released the mic before the command
    // session grabs it.
    await _wakeWord.stopListening();
    _setPhase(VoiceAssistantPhase.waking);
    final session = await _orchestrator.startSession();
    if (session == null) {
      // Could not start (already active or blocked) — fall back to idle and
      // re-arm wake detection so we are not stuck.
      _setPhase(VoiceAssistantPhase.idle);
      await armWakeWord();
    }
    return session;
  }

  /// Explicit user dismissal of the session (pill close / stop button).
  Future<void> stop() async {
    await _orchestrator.stopSession();
    _setPhase(VoiceAssistantPhase.idle);
    await armWakeWord();
  }

  /// User interruption while AURA is speaking (barge-in). Delegates to the
  /// orchestrator, which reuses the single TTS/STT pipeline.
  Future<bool> bargeIn() => _orchestrator.bargeIn();

  // ── Internal state bridging ──

  void _onOrchestratorState(LiveModeState state) {
    if (_disposed) return;
    switch (state) {
      case LiveModeState.idle:
        // Only reflect idle if we are not mid-wake (waking shows the pill
        // before the orchestrator has moved to listening).
        if (_phase != VoiceAssistantPhase.waking) {
          _setPhase(VoiceAssistantPhase.idle);
        }
        break;
      case LiveModeState.listening:
        _setPhase(VoiceAssistantPhase.listening);
        break;
      case LiveModeState.processing:
        _setPhase(VoiceAssistantPhase.thinking);
        break;
      case LiveModeState.speaking:
        _setPhase(VoiceAssistantPhase.speaking);
        // Arm automatic acoustic barge-in for the duration of SPEAKING.
        _bargeIn?.arm();
        break;
      case LiveModeState.error:
        _setPhase(VoiceAssistantPhase.error);
        break;
    }
  }

  void _onSessionEnded() {
    _setPhase(VoiceAssistantPhase.idle);
    // Re-arm wake detection for the next "Hey AURA".
    armWakeWord();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _stateSub?.cancel();
    _stateSub = null;
    await _wakeEngineSub?.cancel();
    _wakeEngineSub = null;
    await _bargeIn?.disarm();
    await disarmWakeWord();
    await _phaseController.close();
  }
}
