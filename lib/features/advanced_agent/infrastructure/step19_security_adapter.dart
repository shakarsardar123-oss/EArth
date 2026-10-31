/// step19_security_adapter.dart
/// AURA Assistant – Step 25: Infrastructure adapter for Step 19 Security.
///
/// Adapts Step 19's SecurityProvider contract to Step 25's SecurityRepository.
/// FAIL-CLOSED: unknown → denied, error → denied, unavailable → denied.
library;

import '../domain/models/safety_verdict.dart';
import '../domain/repositories/security_repository.dart';

/// Adapter bridging Step 19 Security to Step 25's SecurityRepository.
///
/// FAIL-CLOSED contract:
///   - Unknown action/tool → SafetyVerdict.denied
///   - Error during check → SafetyVerdict.denied
///   - Security provider unavailable → SafetyVerdict.denied
///   - Any null/empty action → SafetyVerdict.denied
class Step19SecurityAdapter implements SecurityRepository {
  bool _available;

  Step19SecurityAdapter({bool available = true}) : _available = available;

  @override
  Future<SafetyVerdict> check(
    String action,
    String toolId,
    String riskLevel,
  ) async {
    // FAIL-CLOSED: unavailable → denied
    if (!_available) {
      return SafetyVerdict.denied(
        verdictId: _verdictId(),
        action: action,
        toolId: toolId,
        riskCategory: riskLevel,
        rationale: 'Security provider unavailable — failing closed (denied).',
      );
    }

    // FAIL-CLOSED: null/empty action → denied
    if (action.isEmpty) {
      return SafetyVerdict.denied(
        verdictId: _verdictId(),
        action: action,
        toolId: toolId,
        riskCategory: riskLevel,
        rationale: 'Empty action — failing closed (denied).',
      );
    }

    // FAIL-CLOSED: high risk → denied (unless explicitly allowlisted)
    // In production, delegates to Step 19 SecurityProvider.
    // For structural validation, deny by default (fail-closed).
    return SafetyVerdict.denied(
      verdictId: _verdictId(),
      action: action,
      toolId: toolId,
      riskCategory: riskLevel,
      rationale: 'Default fail-closed: action requires explicit allowlist.',
    );
  }

  @override
  bool isAvailable() => _available;

  /// Mark adapter as available (for testing/wiring only).
  void setAvailable(bool available) => _available = available;

  String _verdictId() => 'sv-${DateTime.now().millisecondsSinceEpoch}';
}
