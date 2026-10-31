/// advanced_agent.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Top-level barrel file for the advanced_agent feature module.
/// Exports all sub-modules: domain, application, infrastructure, presentation.
///
/// FAIL-CLOSED design: unknown → denied, error → denied, unavailable → denied.
/// Locale: Kurdish Sorani (ku) RTL-first.
library;

// Domain layer – models, services, repositories
export 'domain/domain.dart';

// Application layer – providers, coordinator
export 'application/application.dart';

// Infrastructure layer – repository adapters
export 'infrastructure/infrastructure.dart';

// Presentation layer – UI state models
export 'presentation/presentation.dart';
