/// Phase 6 — Resource Optimization Tool.
///
/// Reads real RAM usage and performs a genuine, bounded resource-
/// optimization pass via the [SystemControlChannel].
///
/// **Honesty:** the actuation only does what an unprivileged app may
/// legitimately do — release the app's own caches, hint the VM to collect,
/// and (when KILL_BACKGROUND_PROCESSES is held) ask the OS to trim other
/// apps' background processes. The result reports the VERIFIED before/after
/// available-memory delta from `ActivityManager.MemoryInfo`; it never
/// fabricates a "freed" figure.
library;

import '../tool.dart';
import '../tool_definition.dart';
import '../tool_permission.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../../agent/agent_confirmation_manager.dart';
import '../../device/system_control_channel.dart';
import '../../../core/errors/result.dart';

class ResourceOptimizationTool extends Tool {
  final SystemControlChannel _channel;

  ResourceOptimizationTool(this._channel);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'resource_optimization',
        description:
            'بەکارهێنانی رام بخوێنیتەوە یان پاککردنەوەی بیرگە ئەنجام بدە. '
            '— '
            'Read RAM usage (action=status) or run a real memory-optimization '
            'pass (action=optimize) and report the verified freed bytes.',
        category: 'device',
        parameters: [
          ToolArgumentDef(
            name: 'action',
            type: 'string',
            description:
                'کردار: status (خوێندنەوە), optimize (پاککردنەوە). '
                '— Action: status (read RAM), optimize (run pass).',
            isRequired: false,
            defaultValue: 'status',
            enumValues: ['status', 'optimize'],
            example: 'status',
            label: 'کردار',
            hintText: 'status',
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.system,
            isRequired: true,
            rationale:
                'پێویستە ڕێگەی سیستەم بۆ بەرێوەبردنی باوەری سیستەم. '
                '— System permission is required to inspect and optimize memory.',
          ),
        ],
        isDangerous: false,
        // Reading is safe; optimize has a visible but non-destructive effect.
        requiresConfirmation: false,
        tags: ['device', 'memory', 'ram', 'optimize', 'رام', 'پاککردنەوە'],
        icon: 'memory',
        timeout: Duration(seconds: 20),
        riskLevel: ToolRiskLevel.low,
      );

  @override
  Future<ToolResult> execute(ToolArguments arguments) async {
    final action = arguments.getOrElse<String>('action', 'status');

    if (action != 'status' && action != 'optimize') {
      return const ToolResult.failure(
        'action must be status or optimize. '
        '— کردار دەبێت status یان optimize بێت.',
        errorCode: 'invalidArguments',
      );
    }

    try {
      final r = action == 'optimize'
          ? await _channel.optimizeResources()
          : await _channel.getMemoryInfo();
      if (!r.isSuccess) {
        return ToolResult.failure(
          r.errorMessage ?? 'Resource channel error',
          errorCode: r.errorCode,
        );
      }
      final data = Map<String, dynamic>.from(r.data ?? {});
      data['action'] = action;
      return ToolResult.success(data);
    } catch (e) {
      return ToolResult.failure(
        'Resource optimization error: $e',
        errorCode: 'internalError',
      );
    }
  }
}
