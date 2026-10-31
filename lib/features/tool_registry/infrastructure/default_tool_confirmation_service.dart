/// Step 20 — Default Tool Confirmation Service
///
/// Default implementation of ToolConfirmationService.
/// Prompts user for confirmation before executing high-risk tools.
///
/// AUDIT FIX — Bug #8:
///   Changed method signature to match the abstract interface exactly:
///   OLD: requestConfirmation(ToolDefinition definition, {String? message})
///   NEW: requestConfirmation({required ToolDefinition definition,
///          required Map<String, dynamic> params, String? reason, Duration? timeout})
///
///   - `definition` changed from positional to named required parameter
///   - Added `params` required named parameter (tool execution parameters)
///   - `message` replaced with `reason` (matching abstract interface)
///   - Added `timeout` optional named parameter
///   - Updated constructor callback type to match new signature
///   - Updated internal usages to use `reason` instead of `message`

import '../domain/services/tool_confirmation_service.dart';
import '../domain/models/tool_definition.dart';

typedef ConfirmationCallback = Future<bool> Function({
  required ToolDefinition definition,
  required Map<String, dynamic> params,
  String? reason,
  Duration? timeout,
});

class DefaultToolConfirmationService implements ToolConfirmationService {
  final ConfirmationCallback _onConfirm;

  DefaultToolConfirmationService({required ConfirmationCallback onConfirm})
      : _onConfirm = onConfirm;

  @override
  Future<bool> requestConfirmation({
    required ToolDefinition definition,
    required Map<String, dynamic> params,
    String? reason,
    Duration? timeout,
  }) async {
    // FAIL-CLOSED: if definition is invalid, deny execution.
    if (definition.id.isEmpty) {
      return false;
    }

    try {
      final confirmed = await _onConfirm(
        definition: definition,
        params: params,
        reason: reason,
        timeout: timeout,
      );
      return confirmed;
    } catch (_) {
      // FAIL-CLOSED: any error during confirmation → deny
      return false;
    }
  }
}
