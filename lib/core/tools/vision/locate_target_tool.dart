import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../tool_permission.dart';
import '../../../domain/entities/vision/vision_entities.dart';
import '../../../services/vision/vision_service.dart';
import '../../../core/errors/result.dart';

/// Tool to locate a specific target in an image using AI vision.
///
/// Finds a target and returns VisionTarget with bounding box
/// suitable for overlay rendering (box, circle, arrow, point).
class LocateTargetTool extends Tool {
  final VisionService _visionService;

  LocateTargetTool(this._visionService);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'locate_target',
        description:
            'Locate a specific target in an image and return its position with visual overlay instructions (box, circle, arrow, or point).',
        category: 'vision',
        parameters: [
          ToolArgumentDef(
            name: 'image_base64',
            type: 'string',
            description: 'Base64-encoded JPEG image data',
            isRequired: true,
            isSecret: true,
          ),
          ToolArgumentDef(
            name: 'target_description',
            type: 'string',
            description: 'Description of the target to locate (e.g. "red cup", "person on the left", "stop sign")',
            isRequired: true,
          ),
          ToolArgumentDef(
            name: 'overlay_style',
            type: 'string',
            description: 'Visual overlay style for marking the target',
            isRequired: false,
            defaultValue: 'rect',
            enumValues: ['rect', 'circle', 'arrow', 'point'],
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.camera,
            isRequired: true,
            rationale: 'Target locating requires camera access',
          ),
          ToolPermissionRequirement(
            permission: ToolPermission.network,
            isRequired: true,
            rationale: 'AI target locating requires internet to reach the vision API',
          ),
        ],
        tags: ['vision', 'camera', 'ai', 'locate', 'overlay'],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final imageBase64 = args.get<String>('image_base64');
    final targetDescription = args.get<String>('target_description');
    final overlayStyleStr = args.getOrElse<String>('overlay_style', 'rect');

    if (imageBase64.isEmpty) {
      return const ToolResult.failure('image_base64 cannot be empty');
    }
    if (targetDescription.isEmpty) {
      return const ToolResult.failure('target_description cannot be empty');
    }

    // Map overlay style string to enum.
    final overlayStyle = BoundingBoxStyle.values.firstWhere(
      (e) => e.name == overlayStyleStr,
      orElse: () => BoundingBoxStyle.rect,
    );

    try {
      final result = await _visionService.locateTarget(
        imageBase64: imageBase64,
        targetDescription: targetDescription,
        overlayStyle: overlayStyle.name,
      );

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'Target not found',
          errorCode: 'TARGET_NOT_FOUND',
        );
      }

      return ToolResult.success(result.toJson());
    } catch (e) {
      return ToolResult.failure('Locate target error: $e', errorCode: 'VISION_EXCEPTION');
    }
  }
}
