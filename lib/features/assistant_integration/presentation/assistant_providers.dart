/// Presentation-layer Riverpod integration for assistant feature.
///
/// Wires the [AssistantController] into the Riverpod provider graph
/// so the UI can watch state changes reactively.
///
/// Follows the project convention of defining provider names
/// in an abstract class and providing creator functions.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../../../core/agent/agent_engine.dart';
import '../../../core/voice_screen/voice_screen_service.dart';
import '../../../services/voice/voice_service.dart';
import '../domain/assistant_service.dart';
import '../application/assistant_controller.dart';
import '../application/assistant_providers.dart';
import '../infrastructure/assistant_method_channel.dart';

/// Create the production [AssistantService] (MethodChannel-based).
AssistantService createAssistantService() => AssistantMethodChannel();

/// Create the production [AssistantController].
AssistantController createProductionAssistantController({
  required AgentEngine agentEngine,
  required VoiceScreenService voicePipeline,
  required VoiceService voiceService,
}) =>
    AssistantController(
      service: createAssistantService(),
      agentEngine: agentEngine,
      voicePipeline: voicePipeline,
    voiceService: voiceService,
    );

/// Presentation-layer provider names for Riverpod registration.
/// These complement the application-layer [AssistantIntegrationProviders].
abstract class AssistantPresentationProviders {
  static const String statusAsync = 'assistantStatusAsyncProvider';
  static const String lifecycleAsync = 'assistantLifecycleAsyncProvider';
  static const String canRequestDefaultProvider =
      'canRequestDefaultAssistantProvider';
  static const String isActiveDefaultProvider =
      'isActiveDefaultAssistantProvider';
  static const String currentInvocationProvider =
      'currentAssistantInvocationProvider';
  static const String hasErrorProvider = 'assistantHasErrorProvider';
  static const String errorMessageProvider = 'assistantErrorMessageProvider';
}
