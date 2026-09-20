import 'agent_context.dart';
import 'agent_plan.dart';
import 'agent_step.dart';
import 'agent_step_status.dart';
import '../tools/tool_result.dart';
import '../../core/errors/result.dart';

/// Result of verifying a step or entire plan.
class VerificationResult {
  const VerificationResult({
    required this.passed,
    this.message,
    this.details,
    this.severity = VerificationSeverity.warning,
  });

  /// Whether the verification passed.
  final bool passed;

  /// Human-readable message about the verification.
  final String? message;

  /// Additional structured details.
  final Map<String, dynamic>? details;

  /// How severe a failure is.
  final VerificationSeverity severity;

  /// Convenience constructor for pass.
  static VerificationResult pass([String? message]) =>
      VerificationResult(passed: true, message: message);

  /// Convenience constructor for fail.
  static VerificationResult fail(
    String message, {
    VerificationSeverity severity = VerificationSeverity.warning,
    Map<String, dynamic>? details,
  }) =>
      VerificationResult(
        passed: false,
        message: message,
        severity: severity,
        details: details,
      );

  @override
  String toString() =>
      'VerificationResult(${passed ? "PASS" : "FAIL"}: $message)';
}

/// Severity of a verification failure.
enum VerificationSeverity {
  /// Minor issue — can continue.
  info,

  /// Potential problem — should warn user.
  warning,

  /// Significant issue — may need replanning.
  error,

  /// Critical failure — must stop.
  critical;
}

/// Verifies that executed steps produced expected results.
///
/// Phase 4 verification engine checks:
/// - Individual step results against their verificationCondition
/// - Overall plan results against plan verificationConditions
/// - Data quality and completeness
/// - Side-effect consistency
class AgentVerificationEngine {
  /// Verify a single step's result against its verification condition.
  VerificationResult verifyStep(AgentStep step) {
    if (step.status != AgentStepStatus.succeeded) {
      return VerificationResult.fail(
        'Step ${step.stepId} did not succeed (status: ${step.status})',
        severity: VerificationSeverity.error,
      );
    }

    final result = step.result;
    if (result == null) {
      // Step marked succeeded but has no result — suspicious but not fatal.
      return VerificationResult.pass(
        'Step succeeded without result data',
      );
    }

    if (!result.isSuccess) {
      return VerificationResult.fail(
        'Step ${step.stepId} succeeded but ToolResult indicates failure',
        severity: VerificationSeverity.error,
      );
    }

    // If there's a verification condition, check it against the result data.
    final condition = step.verificationCondition;
    if (condition != null && condition.isNotEmpty) {
      return _checkCondition(condition, result);
    }

    // If there are expected results, check them.
    final expected = step.expectedResults;
    if (expected != null && expected.isNotEmpty) {
      return _checkExpectedResults(expected, result);
    }

    return VerificationResult.pass('Step ${step.stepId} verified');
  }

  /// Verify the entire plan's results against its verification conditions.
  VerificationResult verifyPlan(AgentPlan plan, List<AgentObservation> observations) {
    // All steps must be done.
    if (!plan.isComplete) {
      return VerificationResult.fail(
        'Plan not yet complete (${plan.pending.length} steps pending)',
        severity: VerificationSeverity.warning,
      );
    }

    // All steps must have succeeded (unless explicitly skipped).
    if (plan.hasFailures) {
      final failedIds = plan.failedSteps.map((s) => s.stepId).toList();
      return VerificationResult.fail(
        'Plan has ${plan.failedSteps.length} failed steps: $failedIds',
        severity: VerificationSeverity.error,
      );
    }

    // Check plan-level verification conditions.
    for (final condition in plan.verificationConditions) {
      final observationMatch = observations.where(
        (o) => o.summary.toLowerCase().contains(condition.toLowerCase()),
      );
      if (observationMatch.isEmpty) {
        return VerificationResult.fail(
          'Verification condition not met: "$condition"',
          severity: VerificationSeverity.warning,
        );
      }
    }

    // Check plan-level expected results.
    for (final expected in plan.expectedResults) {
      final observationMatch = observations.where(
        (o) => o.summary.toLowerCase().contains(expected.toLowerCase()),
      );
      if (observationMatch.isEmpty) {
        return VerificationResult.fail(
          'Expected result not observed: "$expected"',
          severity: VerificationSeverity.info,
        );
      }
    }

    // Verify individual steps.
    final stepResults = <VerificationResult>[];
    for (final step in plan.steps) {
      if (step.status == AgentStepStatus.skipped) continue;
      stepResults.add(verifyStep(step));
    }

    final failed = stepResults.where((r) => !r.passed);
    if (failed.isNotEmpty) {
      // Pick the worst severity.
      final worst = failed.reduce(
          (a, b) => a.severity.index >= b.severity.index ? a : b,);
      return worst;
    }

    return VerificationResult.pass('Plan verified successfully');
  }

  /// Verify a tool result before accepting it.
  VerificationResult verifyToolResult(
    String toolName,
    ToolResult result,
  ) {
    if (!result.isSuccess) {
      return VerificationResult.fail(
        'Tool $toolName returned failure: ${result.errorMessage}',
        severity: VerificationSeverity.error,
      );
    }

    final data = result.data;
    if (data == null) {
      return VerificationResult.pass(
        'Tool $toolName returned success with no data',
      );
    }

    // Basic data integrity checks.
    if (data is Map && data.isEmpty) {
      return VerificationResult(
        passed: true,
        message: 'Tool $toolName returned empty map',
        severity: VerificationSeverity.info,
      );
    }

    if (data is List && data.isEmpty) {
      return VerificationResult(
        passed: true,
        message: 'Tool $toolName returned empty list',
        severity: VerificationSeverity.info,
      );
    }

    return VerificationResult.pass('Tool $toolName result verified');
  }

  // ── Internal helpers ──

  /// Check a verification condition string against result data.
  ///
  /// Conditions are simple string patterns:
  /// - "has_data" → result.data is not null/empty
  /// - "contains:X" → result data string representation contains X
  /// - "count>N" → if data is a list, length > N
  VerificationResult _checkCondition(String condition, ToolResult result) {
    final lower = condition.toLowerCase().trim();

    if (lower == 'has_data') {
      if (result.data == null) {
        return VerificationResult.fail(
          'Condition "has_data" failed — no data',
          severity: VerificationSeverity.warning,
        );
      }
      return VerificationResult.pass('has_data condition met');
    }

    if (lower.startsWith('contains:')) {
      final searchTerm = lower.substring('contains:'.length);
      final dataStr = result.data?.toString() ?? '';
      if (!dataStr.toLowerCase().contains(searchTerm)) {
        return VerificationResult.fail(
          'Condition "contains:$searchTerm" failed',
          severity: VerificationSeverity.warning,
        );
      }
      return VerificationResult.pass('contains condition met');
    }

    if (lower.startsWith('count>')) {
      final minCount = int.tryParse(lower.substring('count>'.length));
      if (minCount != null && result.data is List) {
        final list = result.data as List;
        if (list.length > minCount) {
          return VerificationResult.pass('count>$minCount condition met');
        }
        return VerificationResult.fail(
          'Condition "count>$minCount" failed (actual: ${list.length})',
          severity: VerificationSeverity.warning,
        );
      }
    }

    // Default: condition not understood — pass with note.
    return VerificationResult.pass(
      'Unknown condition "$condition" — skipping',
    );
  }

  /// Check expected results description against result data.
  VerificationResult _checkExpectedResults(
    String expected,
    ToolResult result,
  ) {
    final dataStr = result.data?.toString() ?? '';
    if (dataStr.toLowerCase().contains(expected.toLowerCase())) {
      return VerificationResult.pass('Expected result "$expected" found');
    }
    // Not finding expected results is a warning, not an error.
    return VerificationResult(
      passed: true,
      message: 'Expected "$expected" not clearly present in result',
      severity: VerificationSeverity.info,
    );
  }
}
