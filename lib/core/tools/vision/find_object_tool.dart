import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../tool_permission.dart';
import '../../../services/vision/vision_service.dart';
import '../../../core/errors/result.dart';

/// Tool to find a specific object in an image using AI vision.
///
/// Locates a named object and returns bounding box coordinates
/// suitable for overlay rendering.
class FindObjectTool extends Tool {
  final VisionService _visionService;

  FindObjectTool(this._visionService);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'find_object',
        description:
            'Find a specific object in an image and return its location as a bounding box.',
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
            name: 'object_name',
            type: 'string',
            description: 'Name of the object to find (e.g. "cup", "phone", "person")',
            isRequired: true,
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.camera,
            isRequired: true,
            rationale: 'Object detection requires camera access',
          ),
          ToolPermissionRequirement(
            permission: ToolPermission.network,
            isRequired: true,
            rationale: 'AI vision requires internet to reach the vision API',
          ),
        ],
        tags: ['vision', 'camera', 'ai', 'object-detection'],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final imageBase64 = args.get<String>('image_base64');
    final objectName = args.get<String>('object_name');

    if (imageBase64.isEmpty) {
      return const ToolResult.failure('image_base64 cannot be empty');
    }
    if (objectName.isEmpty) {
      return const ToolResult.failure('object_name cannot be empty');
    }

    try {
      final result = await _visionService.findObject(
        imageBase64: imageBase64,
        objectName: objectName,
      );

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'Object not found',
          errorCode: 'OBJECT_NOT_FOUND',
        );
      }

      return ToolResult.success(result.toJson());
    } catch (e) {
      return ToolResult.failure('Find object error: $e', errorCode: 'VISION_EXCEPTION');
    }
  }
}
