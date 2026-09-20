/// Step 23 — Presentation UI Providers
///
/// Wires application-layer providers to presentation-layer state.
/// Does NOT import Flutter SDK — structural validation only.
///
/// OrchestrationProviders is a pure factory class with NO localization field.
/// AppLocalizationService must be injected as a separate dependency.
/// OrchestrationUiState.initial() takes NO arguments.
/// OrchestrationUiState.fromContext(UnifiedRequestContext) replaces fromDomain.

import '../../application/providers/orchestration_providers.dart';
import '../../application/localization_service.dart';
import '../state/orchestration_state.dart';
import '../../domain/orchestration_domain.dart';

class OrchestrationUiProviders {
  final OrchestrationProviders _appProviders;
  final AppLocalizationService _localization;

  OrchestrationUiProviders(
    this._appProviders,
    this._localization,
  );

  /// Get the current localization service.
  AppLocalizationService get localization => _localization;

  /// Create initial UI state.
  /// OrchestrationUiState.initial() takes NO arguments.
  OrchestrationUiState initialState() {
    return OrchestrationUiState.initial();
  }

  /// Map a domain context to a UI state.
  /// Uses fromContext(UnifiedRequestContext), NOT fromDomain(state, label).
  OrchestrationUiState mapToUi(UnifiedRequestContext ctx) {
    return OrchestrationUiState.fromContext(ctx);
  }

  /// Create a UI state with a localized phase label from context.
  /// First builds the UI state from context, then enriches with localized label.
  OrchestrationUiState mapToUiWithLabel(UnifiedRequestContext ctx) {
    final uiState = OrchestrationUiState.fromContext(ctx);
    final label = _localization.translate(
      'status.${ctx.state.phase.name}',
      ctx.locale,
    );
    // Store localized label in errorMessage field for UI display
    // (presentation convenience, not an actual error)
    return uiState.copyWith(errorMessage: label);
  }
}
