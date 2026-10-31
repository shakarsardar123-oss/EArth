/// Barrel export for the Assistant Integration feature.
///
/// Step 15 – Android Default Assistant Integration.
/// Provides role detection, default-assistant request, invocation handling,
/// voice invocation, and Android platform-channel wiring.
library;

// Domain – entities
export 'domain/entities/assistant_status.dart';
export 'domain/entities/assistant_invocation.dart';

// Domain – models & service contract
export 'domain/models/assistant_failure.dart';
export 'domain/models/assistant_state.dart';
export 'domain/assistant_service.dart';

// Application
export 'application/assistant_controller.dart';
export 'application/assistant_providers.dart';

// Infrastructure
export 'infrastructure/assistant_method_channel.dart';
export 'infrastructure/stub_assistant_service.dart';

// Presentation
export 'presentation/assistant_providers.dart';
