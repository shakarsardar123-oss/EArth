/// Riverpod provider definitions for the assistant integration feature.
///
/// Follows the project convention: abstract class with String name
/// constants + typedef creator signatures.
library;

import '../../../core/agent/agent_engine.dart';
import '../../../core/voice_screen/voice_screen_service.dart';
import '../../../services/voice/voice_service.dart';
import '../domain/assistant_service.dart';
import 'assistant_controller.dart';

/// Provider creator signature — matches how Riverpod providers are
/// typically wired in this project.
typedef AssistantControllerProvider = AssistantController Function();

/// Create an [AssistantController] with all required dependencies.
AssistantController createAssistantController({
  required AssistantService service,
  required AgentEngine agentEngine,
  required VoiceScreenService voicePipeline,
  required VoiceService voiceService,
}) =>
    AssistantController(
      service: service,
      agentEngine: agentEngine,
      voicePipeline: voicePipeline,
    voiceService: voiceService,
    );

/// Provider names for Riverpod registration.
/// In the full project, these become `Provider` / `StateNotifierProvider`
/// definitions registered in the main provider file.
abstract class AssistantIntegrationProviders {
  static const String controller = 'assistantControllerProvider';
  static const String state = 'assistantStateProvider';
  static const String status = 'assistantStatusProvider';
  static const String lifecycle = 'assistantLifecycleProvider';
  static const String invocation = 'assistantInvocationProvider';
  static const String service = 'assistantServiceProvider';
}
