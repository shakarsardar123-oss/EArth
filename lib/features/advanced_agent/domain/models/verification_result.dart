/// verification_result.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Result of verifying a task step's output (capability 4).
/// FAIL-CLOSED: default status is [VerificationStatus.failed].
library;

import 'verification_status.dart';

/// A request to verify the output of a specific task step.
class VerificationRequest {
  final String requestId;
  final String stepId;
  final String planId;
  final String expectedOutcome;
  final String? actualOutcome;
  final String locale;

  const VerificationRequest({
    required this.requestId,
    required this.stepId,
    required this.planId,
    required this.expectedOutcome,
    this.actualOutcome,
    this.locale = 'ku',
  });

  @override
  String toString() =>
      'VerificationRequest(step: $stepId, plan: $planId, locale: $locale)';
}

/// The outcome of verifying a task step result.
class VerificationResult {
  final String verificationId;
  final String stepId;
  final String planId;
  final VerificationStatus status;
  final String? message;
  final double confidence;
  final String locale;
  final DateTime verifiedAt;

  const VerificationResult({
    required this.verificationId,
    required this.stepId,
    required this.planId,
    this.status = VerificationStatus.failed,
    this.message,
    this.confidence = 0.0,
    this.locale = 'ku',
    required this.verifiedAt,
  });

  /// Whether the verification passed.
  bool get isPassed => status == VerificationStatus.passed;

  /// FAIL-CLOSED: whether the result should be treated as a failure.
  /// Inconclusive → failed, skipped → depends on context but defaults to fail.
  bool get treatAsFailed =>
      status == VerificationStatus.failed ||
      status == VerificationStatus.inconclusive;

  /// Factory: verification passed.
  factory VerificationResult.passed({
    required String verificationId,
    required String stepId,
    required String planId,
    String? message,
    double confidence = 1.0,
    String locale = 'ku',
  }) =>
      VerificationResult(
        verificationId: verificationId,
        stepId: stepId,
        planId: planId,
        status: VerificationStatus.passed,
        message: message ?? 'Verification passed.',
        confidence: confidence,
        locale: locale,
        verifiedAt: DateTime.now(),
      );

  /// Factory: verification failed.
  factory VerificationResult.failed({
    required String verificationId,
    required String stepId,
    required String planId,
    required String message,
    double confidence = 0.0,
    String locale = 'ku',
  }) =>
      VerificationResult(
        verificationId: verificationId,
        stepId: stepId,
        planId: planId,
        status: VerificationStatus.failed,
        message: message,
        confidence: confidence,
        locale: locale,
        verifiedAt: DateTime.now(),
      );

  /// Factory: verification skipped (safe degradation).
  factory VerificationResult.skipped({
    required String verificationId,
    required String stepId,
    required String planId,
    String? message,
    String locale = 'ku',
  }) =>
      VerificationResult(
        verificationId: verificationId,
        stepId: stepId,
        planId: planId,
        status: VerificationStatus.skipped,
        message: message ?? 'Verification skipped (no verifier available).',
        confidence: 0.0,
        locale: locale,
        verifiedAt: DateTime.now(),
      );

  VerificationResult copyWith({
    String? verificationId,
    String? stepId,
    String? planId,
    VerificationStatus? status,
    String? message,
    double? confidence,
    String? locale,
    DateTime? verifiedAt,
  }) =>
      VerificationResult(
        verificationId: verificationId ?? this.verificationId,
        stepId: stepId ?? this.stepId,
        planId: planId ?? this.planId,
        status: status ?? this.status,
        message: message ?? this.message,
        confidence: confidence ?? this.confidence,
        locale: locale ?? this.locale,
        verifiedAt: verifiedAt ?? this.verifiedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerificationResult && verificationId == other.verificationId;

  @override
  int get hashCode => verificationId.hashCode;

  @override
  String toString() =>
      'VerificationResult(id: $verificationId, step: $stepId, '
      'status: $status, confidence: $confidence)';
}
