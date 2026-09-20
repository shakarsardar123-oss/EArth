/// unknown_tool_handler.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// UnknownToolHandler — catches unrecognized tool IDs.
/// Category: unknown
/// Risk: critical (fail-closed handler — ALWAYS denies unknown tools)
/// Offline: yes
/// Voice-safe: yes
///
/// FAIL CLOSED: every execution returns denied/failure.
/// This tool is the last-resort handler — it NEVER executes unknown tools.
library;

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class UnknownToolHandler extends Tool {
  final String _unknownToolId;

  UnknownToolHandler({required String unknownToolId})
      : _unknownToolId = unknownToolId;

  @override
  String get id => 'aura.tool.unknown.$_unknownToolId';

  @override
  String get name => 'Unknown Tool Handler';

  @override
  ToolCategory get category => ToolCategory.unknown;

  @override
  String get description =>
      'FAIL-CLOSED handler for unrecognized tool: $_unknownToolId';

  @override
  String get version => '1.0.0';

  @override
  List<String> get requiredPermissions => []; // No permissions — never executes

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.critical; // Unknown = highest risk

  @override
  bool get requiresConfirmation => true; // Would need confirmation if it could execute

  @override
  bool get supportsOffline => true;

  @override
  bool get isVoiceSafe => true;

  @override
  int get defaultTimeoutMs => 0; // Immediate failure — no timeout needed

  bool _isExecuting = false;

  @override
  bool get isExecuting => _isExecuting;

  /// FAIL CLOSED: always returns denied for unknown tools.
  /// No unknown tool is ever executed — this is a security guarantee.
  @override
  Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async {
    _isExecuting = true;
    try {
      return ToolOutput.denied(
        toolId: id,
        reason: 'Tool "$_unknownToolId" is not recognized. '
            'Execution denied by FAIL-CLOSED policy.',
        errorCode: 'UNKNOWN_TOOL',
      );
    } finally {
      _isExecuting = false;
    }
  }

  @override
  ToolInput validate(Map<String, dynamic> params) {
    return ToolInput.invalid(
      toolId: id,
      rawParams: params,
      field: 'toolId',
      message: 'Tool "$_unknownToolId" is not registered',
    );
  }

  @override
  String describe() =>
      'ئامرازی نەناسراو: "$_unknownToolId" — ڕەتکرایەوە بەپێی سیاسەتی داخراو'; // Kurdish Sorani

  @override
  void cancel() {}
}
