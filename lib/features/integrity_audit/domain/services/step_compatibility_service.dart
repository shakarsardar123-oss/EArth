/// step_compatibility_service.dart
/// AURA Assistant – Step 26: Domain service for step-to-step compatibility.
///
/// Generates [CompatibilityReport]s aggregating all interface
/// comparisons between a pair of steps.
///
/// FAIL-CLOSED: any drift in any interface → report.isCompatible = false.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import '../models/compatibility_report.dart';
import '../models/integrity_verdict.dart';

/// Abstract interface for step compatibility checking.
///
/// Implementations aggregate interface comparisons into compatibility
/// reports, track drift history, and flag critical mismatches.
abstract class StepCompatibilityService {
  /// Generate a compatibility report between two steps.
  ///
  /// FAIL-CLOSED: any drift → isCompatible = false.
  Future<CompatibilityReport> generateReport({
    required String referenceStep,
    required String comparedStep,
    required String locale,
  });

  /// Get all known drift findings between two steps.
  ///
  /// Returns only [IntegrityVerdict]s with [IntegrityStatus.incompatible]
  /// or [IntegrityStatus.missing].
  Future<List<IntegrityVerdict>> getDrifts({
    required String referenceStep,
    required String comparedStep,
  });

  /// Get critical-severity drifts between two steps.
  ///
  /// FAIL-CLOSED: critical drifts must be addressed before integration.
  Future<List<IntegrityVerdict>> getCriticalDrifts({
    required String referenceStep,
    required String comparedStep,
  });

  /// Check whether two steps are compatible enough for integration.
  ///
  /// FAIL-CLOSED: any critical or high drift → false.
  Future<bool> canIntegrate({
    required String referenceStep,
    required String comparedStep,
    required String locale,
  });
}
