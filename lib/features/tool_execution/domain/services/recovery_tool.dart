/// recovery_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// Recovery tool — handles retry/recovery logic.
/// KEY FIX: uses context.retryAttempt (not recoveryAttempt/currentRetry).
/// riskLevel is String. All API conventions per Step 22 spec.
///
/// FAIL CLOSED: recovery failures default to failClosed.
library;

import '../models/tool_output.dart';
import '../models/tool_execution_context.dart';

class RecoveryTool {
  final int maxRetries;

  RecoveryTool({this.maxRetries = 3});

  /// Determine if recovery is possible based on context.
  /// Uses context.retryAttempt (the canonical field name).
  bool canRecover(ToolExecutionContext context) {
    return context.retryAttempt < maxRetries;
  }

  /// Attempt recovery by incrementing retry count.
  /// Returns new context with incremented retry.
  ToolExecutionContext prepareRecovery(ToolExecutionContext context) {
    return context.incrementRetry();
  }

  /// Build a recovery ToolOutput.
  ToolOutput buildRecoveryOutput(ToolExecutionContext context) {
    if (!canRecover(context)) {
      return ToolOutput.failClosed(
        toolId: 'recovery',
        reason: 'Max retries (${context.retryAttempt}) exceeded — recovery denied',
      );
    }
    return ToolOutput.success(
      toolId: 'recovery',
      data: {'retryAttempt': context.retryAttempt, 'maxRetries': maxRetries},
      message: 'Recovery prepared — attempt ${context.retryAttempt + 1}',
    );
  }
}
