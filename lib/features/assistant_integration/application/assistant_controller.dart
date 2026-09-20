/// Controller that orchestrates the assistant integration lifecycle.
///
/// Responsibilities:
/// 1. Detect assistant role availability.
/// 2. Guide the user through requesting default-assistant status.
/// 3. Route incoming assistant invocations into the existing
///    [AgentEngine] + [VoiceScreenService] pipeline.
///
/// Follows the same controller pattern as [DeviceIntegrationController].
/// Emits state transitions via callbacks so the presentation layer
/// can rebuild UI reactively.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../../../core/agent/agent_engine.dart';
import '../../../core/voice_screen/voice_screen_service.dart';
import '../../../services/voice/voice_service.dart';
import '../domain/assistant_service.dart';
import '../domain/entities/assistant_status.dart';
import '../domain/entities/assistant_invocation.dart';
import '../domain/models/assistant_failure.dart';
import '../domain/models/assistant_state.dart';

/// Callback signature for state changes.
typedef AssistantStateListener = void Function(AssistantState state);

/// Orchestrates the assistant integration lifecycle.
class AssistantController {
  final AssistantService _service;
  final AgentEngine _agentEngine;
  final VoiceScreenService _voicePipeline;
  final VoiceService _voiceService;

  AssistantState _state;
  final List<AssistantStateListener> _listeners = [];

  AssistantController({
    required AssistantService service,
    required AgentEngine agentEngine,
    required VoiceScreenService voicePipeline,
    required VoiceService voiceService,
    AssistantState? initialState,
  })  : _service = service,
        _agentEngine = agentEngine,
        _voicePipeline = voicePipeline,
        _voiceService = voiceService,
        _state = initialState ??
            AssistantState(updatedAt: DateTime.now());

  /// Current read-only state.
  AssistantState get state => _state;

  /// Register a listener for state changes.
  void addListener(AssistantStateListener listener) {
    _listeners.add(listener);
  }

  /// Remove a previously registered listener.
  void removeListener(AssistantStateListener listener) {
    _listeners.remove(listener);
  }

  void _emit(AssistantState newState) {
    _state = newState;
    for (final l in _listeners) {
      l(newState);
    }
  }

  // ── Lifecycle operations ────────────────────────────────────────────

  /// Step 1: Check whether the platform supports the assistant role.
  Future<Result<AssistantStatus, AssistantFailure>> detectStatus() async {
    _emit(_state.copyWith(
      lifecycle: AssistantLifecycle.checking,
      clearErrorMessage: true,
      updatedAt: DateTime.now(),
    ));

    final result = await _service.detectStatus();

    return result.fold(
      onSuccess: (status) {
        final lifecycle = status.isUnsupported
            ? AssistantLifecycle.unsupported
            : status.isAuraDefault
                ? AssistantLifecycle.active
                : AssistantLifecycle.available;

        _emit(_state.copyWith(
          lifecycle: lifecycle,
          status: status,
          updatedAt: DateTime.now(),
        ));
        return Result.success(status);
      },
      onFailure: (failure) {
        _emit(_state.copyWith(
          lifecycle: AssistantLifecycle.failed,
          errorMessage: failure.message,
          updatedAt: DateTime.now(),
        ));
        return Result.failure(failure);
      },
    );
  }

  /// Step 2: Open the system assistant-settings screen so the user
  /// can explicitly set AURA as the default assistant.
  ///
  /// **Never** changes the default assistant silently — always goes
  /// through the Android system UI.
  Future<Result<void, AssistantFailure>> requestDefaultAssistant() async {
    if (_state.lifecycle != AssistantLifecycle.available) {
      return AssistantFailure.openSettingsFailed(
        StateError('Cannot request default assistant in lifecycle: ${_state.lifecycle}'),
      ).asFailure();
    }

    _emit(_state.copyWith(
      lifecycle: AssistantLifecycle.requesting,
      clearErrorMessage: true,
      updatedAt: DateTime.now(),
    ));

    final result = await _service.openAssistantSettings();

    return result.fold(
      onSuccess: (_) {
        // After settings, we don't know the result immediately —
        // the user must choose in the system UI. Re-check status.
        return detectStatus();
      },
      onFailure: (failure) {
        _emit(_state.copyWith(
          lifecycle: AssistantLifecycle.failed,
          errorMessage: failure.message,
          updatedAt: DateTime.now(),
        ));
        return Result.failure(failure);
      },
    );
  }

  /// Step 3: Handle an incoming assistant invocation.
  ///
  /// Extracts invocation data and routes it through the
  /// [AgentEngine] and [VoiceScreenService].
  Future<Result<void, AssistantFailure>> handleInvocation() async {
    _emit(_state.copyWith(
      lifecycle: AssistantLifecycle.invoked,
      clearErrorMessage: true,
      updatedAt: DateTime.now(),
    ));

    // 1. Get invocation data from the platform.
    final invocationResult = await _service.getInvocationData();

    if (invocationResult.isFailure) {
      _emit(_state.copyWith(
        lifecycle: AssistantLifecycle.failed,
        errorMessage: invocationResult.failureOrNull!.message,
        updatedAt: DateTime.now(),
      ));
      return Result.failure(invocationResult.failureOrNull!);
    }

    final invocation = invocationResult.valueOrNull!;

    _emit(_state.copyWith(
      currentInvocation: invocation,
      updatedAt: DateTime.now(),
    ));

    // 2. Route into the pipeline.
    return _routeInvocation(invocation);
  }

  /// Route the invocation payload into the existing pipeline.
  Future<Result<void, AssistantFailure>> _routeInvocation(
    AssistantInvocation invocation,
  ) async {
    try {
      // If the invocation includes context text, process it directly.
      if (invocation.hasContext) {
        final agentResult = await _agentEngine.run(
          userInput: invocation.assistContext!,
          context: const AgentContext(agentConfig: AgentConfig.defaultConfig),
        );

        if (agentResult.isFailure) {
          return AssistantFailure.pipelineRoutingFailed(
            agentResult.failureOrNull!,
          ).asFailure();
        }

        final agentResponse = agentResult.valueOrNull!;

        // Speak the response using the voice service.
        try {
          await _voiceService.speak(agentResponse.text);
          _emit(_state.copyWith(
            lifecycle: AssistantLifecycle.active,
            updatedAt: DateTime.now(),
          ));
          return Result.success(null);
        } catch (e) {
          return AssistantFailure.voiceInvocationFailed(
            StateError('Voice speak failed: $e'),
          ).asFailure();
        }
      }

      // If no context text, trigger voice listening mode.
      if (invocation.isVoiceTriggered || !invocation.hasContext) {
        final startResult = await _voicePipeline.startInteraction();
        if (startResult.isFailure) {
          return AssistantFailure.voiceInvocationFailed(
            StateError('Voice pipeline start failed'),
          ).asFailure();
        }
        _emit(_state.copyWith(
          lifecycle: AssistantLifecycle.active,
          updatedAt: DateTime.now(),
        ));
        return Result.success(null);
      }

      // Fallback — should not normally happen.
      _emit(_state.copyWith(
        lifecycle: AssistantLifecycle.active,
        updatedAt: DateTime.now(),
      ));
      return Result.success(null);
    } catch (e) {
      _emit(_state.copyWith(
        lifecycle: AssistantLifecycle.failed,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      ));
      return AssistantFailure.pipelineRoutingFailed(e).asFailure();
    }
  }

  /// Reset to the available state after a cancellation.
  void cancel() {
    _emit(_state.copyWith(
      lifecycle: AssistantLifecycle.cancelled,
      clearCurrentInvocation: true,
      clearErrorMessage: true,
      updatedAt: DateTime.now(),
    ));
  }

  /// Reset the state machine to uninitialized.
  void reset() {
    _emit(AssistantState(updatedAt: DateTime.now()));
  }

  /// Re-check the assistant status (e.g. after returning from settings).
  Future<Result<AssistantStatus, AssistantFailure>> refreshStatus() async {
    return detectStatus();
  }

  /// Dispose resources and clear listeners.
  void dispose() {
    _listeners.clear();
  }
}
