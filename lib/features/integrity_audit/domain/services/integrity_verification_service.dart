/// integrity_verification_service.dart
/// AURA Assistant – Step 26: Domain service for integrity verification.
///
/// Compares interface signatures between two steps and produces
/// [IntegrityVerdict]s for each member.
///
/// FAIL-CLOSED: any mismatch → incompatible, any null input → incompatible.
/// Kurdish Sorani RTL-first: locale='ku'.
library;

import '../models/integrity_verdict.dart';

/// Abstract interface for integrity verification between steps.
///
/// Implementations compare repository interfaces, model structures,
/// and adapter contracts across steps to detect drift.
abstract class IntegrityVerificationService {
  /// Compare all interfaces between [referenceStep] and [comparedStep].
  ///
  /// Returns a list of [IntegrityVerdict]s, one per member comparison.
  /// FAIL-CLOSED: any unknown/error → incompatible verdict.
  Future<List<IntegrityVerdict>> compareInterfaces({
    required String referenceStep,
    required String comparedStep,
    required String locale,
  });

  /// Compare a single interface between two steps.
  ///
  /// Returns an [IntegrityVerdict] for the specified [interfaceName].
  Future<IntegrityVerdict> compareInterface({
    required String referenceStep,
    required String comparedStep,
    required String interfaceName,
    required String locale,
  });

  /// Check whether a specific method signature matches between steps.
  ///
  /// FAIL-CLOSED: any param mismatch → incompatible.
  Future<IntegrityVerdict> compareMethodSignature({
    required String referenceStep,
    required String comparedStep,
    required String interfaceName,
    required String methodName,
    required String locale,
  });

  /// Check whether a model's field set matches between steps.
  ///
  /// FAIL-CLOSED: any field difference → incompatible.
  Future<IntegrityVerdict> compareModelStructure({
    required String referenceStep,
    required String comparedStep,
    required String modelName,
    required String locale,
  });

  /// Returns true if all interfaces are compatible (no drift).
  ///
  /// FAIL-CLOSED: any drift → false.
  Future<bool> isFullyCompatible({
    required String referenceStep,
    required String comparedStep,
    required String locale,
  });
}
