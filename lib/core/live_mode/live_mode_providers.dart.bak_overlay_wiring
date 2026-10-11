/// live_mode_providers.dart
/// AURA Assistant – P0 Remediation: Live Mode Riverpod Providers
///
/// Exposes LiveModeOrchestrator and state via Riverpod for UI integration.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../voice/voice_service_provider.dart'
    show voiceServiceImplProvider;
import '../../presentation/providers/app_providers.dart'
    show agentEngineProvider, memoryServiceProvider;
import 'live_mode_state.dart';
import 'live_mode_orchestrator.dart';

/// Whether a Live Mode session is currently active.
final isLiveSessionProvider = StateProvider<bool>((ref) => false);

/// Current Live Mode state for UI.
final liveModeStateProvider =
    StateProvider<LiveModeState>((ref) => LiveModeState.idle);

/// Inactivity/session timeout for the Live Mode voice session.
/// null = no timeout (the session ends only on an explicit spoken exit
/// command or an explicit user dismissal). Read at orchestrator creation.
final liveSessionTimeoutProvider =
    StateProvider<Duration?>((ref) => const Duration(seconds: 30));

/// LiveModeOrchestrator provider.
/// Created lazily on first watch/read; persists across rebuilds.
final liveModeOrchestratorProvider = Provider<LiveModeOrchestrator>((ref) {
  final voiceService = ref.watch(voiceServiceImplProvider);
  final agentEngine = ref.read(agentEngineProvider);
  final memoryService = ref.read(memoryServiceProvider);

  final orchestrator = LiveModeOrchestrator(
    voiceService: voiceService,
    agentProcessor: agentEngine,
    memoryService: memoryService,
    // Phase 5: spoken exit commands use the orchestrator's built-in
    // defaults; the inactivity timeout is taken as a snapshot here so a
    // silence period gently re-prompts once and then returns to IDLE.
    inactivityTimeout: ref.read(liveSessionTimeoutProvider),
  );

  // Wire state changes to providers for UI.
  orchestrator.onStateChanged = (state) {
    // Schedule microtask to avoid modifying providers during build.
    Future.microtask(() {
      ref.read(liveModeStateProvider.notifier).state = state;
      ref.read(isLiveSessionProvider.notifier).state = state.isActive;
    });
  };

  // Clean up when provider is disposed.
  ref.onDispose(() {
    orchestrator.dispose();
  });

  return orchestrator;
});
