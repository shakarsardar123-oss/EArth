/// verification_status.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Status enum for result verification (capability 4).
/// FAIL-CLOSED: unknown status defaults to [failed].
library;

/// The outcome of verifying a task result.
enum VerificationStatus {
  /// Verification not yet started.
  pending,

  /// Verification is in progress.
  inProgress,

  /// Verification passed — result is valid.
  passed,

  /// Verification failed — result is invalid.
  failed,

  /// Verification was skipped (e.g., no verifier available, safe degrade).
  skipped,

  /// Verification inconclusive — cannot determine pass or fail.
  /// FAIL-CLOSED: inconclusive is treated as [failed] by consumers.
  inconclusive,
  ;

  /// Whether this is a terminal verification status.
  bool get isTerminal =>
      this == VerificationStatus.passed ||
      this == VerificationStatus.failed ||
      this == VerificationStatus.skipped;

  /// FAIL-CLOSED: any unknown name maps to [failed].
  static VerificationStatus fromName(String name) {
    return VerificationStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => VerificationStatus.failed,
    );
  }
}
