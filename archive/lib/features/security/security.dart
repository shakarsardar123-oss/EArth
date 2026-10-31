/// security.dart
/// Top-level barrel export for the security feature.
/// Re-exports all layers for convenient single-import access.
library;

// Domain models
export 'domain/models/security.dart';
// Domain services
export 'domain/services/security_services.dart';
// Application layer
export 'application/security_application.dart';
// Infrastructure implementations
export 'infrastructure/security_infrastructure.dart';
// Adapters
export 'adapters/security_adapters.dart';
// Presentation
export 'presentation/security_presentation.dart';
// Localization keys
export 'l10n/security_l10n_keys.dart';
