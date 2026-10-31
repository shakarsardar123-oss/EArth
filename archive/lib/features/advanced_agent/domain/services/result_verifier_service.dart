/// result_verifier_service.dart
/// AURA Assistant – Step 25: Capability 4 — Result Verification
///
/// Abstract service interface for verifying step and plan results.
library;

import '../models/verification_result.dart';
import '../models/advanced_task_plan.dart';

/// Service responsible for verifying that execution results
/// meet the expected outcomes.
abstract class ResultVerifierService {
  /// Verify a single step's result against its expected outcome.
  VerificationResult verifyStep({
    required String stepId,
    required String planId,
    required Map<String, dynamic> actualResult,
    required Map<String, dynamic> expectedOutcome,
    required String locale,
  });

  /// Verify all completed steps in a plan.
  List<VerificationResult> verifyPlan(AdvancedTaskPlan plan);

  /// Check whether a verification result indicates success.
  bool isVerified(VerificationResult result);

  /// Maximum verification retries before marking as unverified.
  int get maxVerificationRetries;
}
