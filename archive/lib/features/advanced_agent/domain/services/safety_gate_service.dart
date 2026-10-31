/// safety_gate_service.dart
/// AURA Assistant – Step 25: Capability 10 — Safety Gate
///
/// Abstract service interface for safety gate enforcement.
/// FAIL-CLOSED: unknown → denied, unavailable → denied, error → denied.
library;

import '../models/safety_verdict.dart';

/// Service responsible for gating actions based on safety policies.
/// Implements the FAIL-CLOSED contract: any unknown, unavailable, or
/// error state MUST result in a denied verdict.
abstract class SafetyGateService {
  /// Evaluate whether an action is allowed to proceed.
  /// FAIL-CLOSED: returns [SafetyVerdict.denied] for any
  /// unknown/unavailable/error case.
  SafetyVerdict evaluate({
    required String action,
    String? toolId,
    String? riskCategory,
    required String locale,
  });

  /// Evaluate whether a plan step is safe to execute.
  SafetyVerdict evaluateStep({
    required String stepId,
    required String planId,
    required String action,
    String? toolId,
    String? riskCategory,
    required String locale,
  });

  /// Whether the safety gate is available.
  /// If unavailable, all evaluations must return denied (fail-closed).
  bool get isAvailable;

  /// FAIL-CLOSED: evaluate availability and return appropriate verdict.
  SafetyVerdict guard({
    required String action,
    String? toolId,
    String? riskCategory,
    required String locale,
  });
}
