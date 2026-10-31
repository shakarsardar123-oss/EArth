/// fail_closed_invariant.dart
/// AURA Assistant – Step 26: Domain model for FAIL-CLOSED invariants.
///
/// Each invariant represents a security/safety rule that MUST hold.
/// FAIL-CLOSED: unknown → denied, error → denied, unavailable → denied,
///              canSkip → shouldAbort (NEVER skip).
library;

/// A single FAIL-CLOSED invariant that must be upheld across all steps.
///
/// Invariants are the backbone of AURA's safety model:
/// - Any unknown input → denied (never allowed through)
/// - Any error → denied (never silently passes)
/// - Any unavailable service → denied (never fabricates data)
/// - Any canSkip path → shouldAbort (NEVER skip safety checks)
class FailClosedInvariant {
  /// Unique invariant identifier.
  final String invariantId;

  /// The step(s) this invariant applies to.
  final List<String> appliesToSteps;

  /// The layer this invariant guards.
  final InvariantLayer layer;

  /// Short description of the invariant.
  final String description;

  /// The input condition that triggers this invariant.
  final String triggerCondition;

  /// The required FAIL-CLOSED outcome when the trigger fires.
  final String requiredOutcome;

  /// Whether this invariant is currently verified (by tests).
  final bool verified;

  const FailClosedInvariant({
    required this.invariantId,
    required this.appliesToSteps,
    required this.layer,
    required this.description,
    required this.triggerCondition,
    required this.requiredOutcome,
    this.verified = false,
  });

  /// Security invariant: unknown action → denied.
  factory FailClosedInvariant.unknownDenied({
    required String invariantId,
    required List<String> steps,
    required String layerName,
  String? description,
  }) {
    return FailClosedInvariant(
      invariantId: invariantId,
      appliesToSteps: steps,
      layer: InvariantLayer.security,
      description: description ?? 'Unknown action/tool → denied (never allowed)',
      triggerCondition: 'Action or tool is unknown/unrecognized',
      requiredOutcome: 'SafetyVerdict.denied',
    );
  }

  /// Error invariant: error during check → denied.
  factory FailClosedInvariant.errorDenied({
    required String invariantId,
    required List<String> steps,
    required String layerName,
    String? description,
  }) {
    return FailClosedInvariant(
      invariantId: invariantId,
      appliesToSteps: steps,
      layer: InvariantLayer.errorHandling,
      description: description ?? 'Error during security check → denied',
      triggerCondition: 'Exception or error during check execution',
      requiredOutcome: 'SafetyVerdict.denied',
    );
  }

  /// Unavailability invariant: service unavailable → denied/null.
  factory FailClosedInvariant.unavailableDenied({
    required String invariantId,
    required List<String> steps,
    required String layerName,
    String? description,
  }) {
    return FailClosedInvariant(
      invariantId: invariantId,
      appliesToSteps: steps,
      layer: InvariantLayer.availability,
      description: description ?? 'Service unavailable → denied/null (never fabricate)',
      triggerCondition: 'Provider/repository is unavailable',
      requiredOutcome: 'Denied or null result',
    );
  }

  /// Skip invariant: canSkip → shouldAbort (NEVER skip safety).
  factory FailClosedInvariant.noSkip({
    required String invariantId,
    required List<String> steps,
    required String layerName,
    String? description,
  }) {
    return FailClosedInvariant(
      invariantId: invariantId,
      appliesToSteps: steps,
      layer: InvariantLayer.recovery,
      description: description ?? 'canSkip → shouldAbort (NEVER skip safety checks)',
      triggerCondition: 'Recovery suggests skipping',
      requiredOutcome: 'shouldAbort (not skip)',
    );
  }

  /// Mark this invariant as verified.
  FailClosedInvariant markVerified() => FailClosedInvariant(
        invariantId: invariantId,
        appliesToSteps: appliesToSteps,
        layer: layer,
        description: description,
        triggerCondition: triggerCondition,
        requiredOutcome: requiredOutcome,
        verified: true,
      );

  /// Whether this invariant is for security layer.
  bool get isSecurity => layer == InvariantLayer.security;

  /// Whether this invariant is for recovery layer.
  bool get isRecovery => layer == InvariantLayer.recovery;

  @override
  String toString() =>
      'FailClosedInvariant($invariantId: $layer, $description)';
}

/// Layers that FAIL-CLOSED invariants guard.
enum InvariantLayer {
  /// Security checks (permission, safety verdict).
  security,

  /// Error handling (exceptions → denied).
  errorHandling,

  /// Service availability (unavailable → denied/null).
  availability,

  /// Recovery (skip → abort).
  recovery,

  /// Tool execution (missing tool → failure).
  execution,

  /// Memory/audit (sensitive data → redacted/null).
  dataIntegrity,
}
