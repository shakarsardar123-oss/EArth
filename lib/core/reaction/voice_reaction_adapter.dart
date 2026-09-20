/// Voice Reaction Adapter — bridges VoiceService state changes into the
/// Dynamic Reaction System.
///
/// This adapter listens to [VoiceService.stateStream] and, on each
/// [VoiceState] change, builds a [ReactionContext] and calls
/// [ReactionEngine.evaluate()].
///
/// Failure isolation: all [ReactionEngine.evaluate()] errors are caught
/// and silently swallowed — adapter failures NEVER propagate to the
/// VoiceService.
///
/// StreamSubscription lifecycle: call [attach()] to start listening,
/// [dispose()] to cancel the subscription.
///
/// Step 3 scope: event integration ONLY. No UI, no animation, no
/// visual output.
library;

import 'dart:async';

import '../../services/voice/voice_service.dart';
import 'reaction_engine.dart';
import 'reaction_context.dart' show ReactionContext, ContextTriggerSource;
import 'reaction_trigger.dart' show ReactionTrigger;

/// Bridges VoiceService state changes into the Reaction subsystem.
///
/// Usage:
/// ```dart
/// final adapter = VoiceReactionAdapter(
///   engine: reactionEngine,
///   voiceService: voiceServiceImpl,
/// );
/// adapter.attach();  // start listening
/// // ...
/// adapter.dispose(); // cancel subscription
/// ```
class VoiceReactionAdapter {
  VoiceReactionAdapter({
    required ReactionEngine engine,
    required VoiceService voiceService,
  })  : _reactionEngine = engine,
        _voiceService = voiceService;

  final ReactionEngine _reactionEngine;
  final VoiceService _voiceService;

  StreamSubscription<VoiceState>? _subscription;

  /// Last observed VoiceState (for debugging/testing).
  VoiceState? _lastVoiceState;
  VoiceState? get lastVoiceState => _lastVoiceState;

  /// Number of times the adapter successfully triggered evaluate().
  int _evaluationCount = 0;
  int get evaluationCount => _evaluationCount;

  /// Number of times evaluate() threw (swallowed by failure isolation).
  int _errorCount = 0;
  int get errorCount => _errorCount;

  /// Whether the adapter is currently attached (listening to stream).
  bool _attached = false;
  bool get isAttached => _attached;

  /// Start listening to [VoiceService.stateStream].
  ///
  /// Safe to call multiple times — extra calls are no-ops if already
  /// attached.
  void attach() {
    if (_attached) return;
    _attached = true;
    _subscription = _voiceService.stateStream.listen(_handleVoiceState);
  }

  /// Cancel the stream subscription and detach from the VoiceService.
  ///
  /// Safe to call multiple times — extra calls are no-ops.
  Future<void> dispose() async {
    if (!_attached) return;
    _attached = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Handle a VoiceState change from the stream.
  void _handleVoiceState(VoiceState newState) {
    _lastVoiceState = newState;
    final stateName = newState.name;

    // Error state maps to errorEvent trigger.
    if (newState == VoiceState.error) {
      _evaluate(
        ReactionTrigger.errorEvent,
        voiceState: stateName,
        urgency: 0.9,
      );
      return;
    }

    // Active states (listening, processing, speaking) get slightly
    // elevated urgency.
    final urgency = newState.isActive ? 0.6 : 0.3;

    _evaluate(
      ReactionTrigger.voiceState,
      voiceState: stateName,
      urgency: urgency,
    );
  }

  /// Build a [ReactionContext] and call [ReactionEngine.evaluate()].
  ///
  /// All errors from evaluate() are caught and swallowed (failure
  /// isolation).
  void _evaluate(
    ReactionTrigger trigger, {
    String? voiceState,
    String? agentState,
    double urgency = 0.5,
  }) {
    final context = ReactionContext(
      trigger: trigger,
      triggerSource: trigger == ReactionTrigger.errorEvent ||
              trigger == ReactionTrigger.toolExecution ||
              trigger == ReactionTrigger.wakeEvent ||
              trigger == ReactionTrigger.idleTimeout ||
              trigger == ReactionTrigger.userTone
          ? ContextTriggerSource.event
          : ContextTriggerSource.stateChange,
      voiceState: voiceState,
      agentState: agentState,
      urgency: urgency,
      timestamp: DateTime.now(),
    );

    try {
      _reactionEngine.evaluate(context);
      _evaluationCount++;
    } catch (e) {
      // Failure isolation — never let reaction errors propagate
      // to the VoiceService.
      _errorCount++;
    }
  }

  /// Reset internal tracking state (does NOT detach).
  void reset() {
    _lastVoiceState = null;
    _evaluationCount = 0;
    _errorCount = 0;
  }
}
