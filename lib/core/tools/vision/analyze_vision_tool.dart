import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../tool_permission.dart';
import '../../../services/vision/vision_service.dart';
import '../../../core/errors/result.dart';

/// Tool to analyze an image using AI vision.
///
/// Performs comprehensive image analysis — objects, scenes, text,
/// and returns structured results with bounding boxes.
class AnalyzeVisionTool extends Tool {
  final VisionService _visionService;

  AnalyzeVisionTool(this._visionService);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'analyze_vision',
        description:
            'Analyze an image using AI vision. Detects objects, scenes, text, and provides descriptions with locations.',
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
            name: 'prompt',
            type: 'string',
            description: 'Optional text prompt to guide the analysis',
            isRequired: false,
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.camera,
            isRequired: true,
            rationale: 'Image analysis requires camera access to capture or select images',
          ),
          ToolPermissionRequirement(
            permission: ToolPermission.network,
            isRequired: true,
            rationale: 'AI vision analysis requires internet to reach the vision API',
          ),
        ],
        tags: ['vision', 'camera', 'ai', 'analysis'],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final imageBase64 = args.get<String>('image_base64');
    final prompt = args.getString('prompt');

    if (imageBase64.isEmpty) {
      return const ToolResult.failure('image_base64 cannot be empty');
    }

    try {
      final result = await _visionService.analyzeImage(
        imageBase64: imageBase64,
        prompt: prompt,
      );

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'Vision analysis failed',
          errorCode: 'VISION_ERROR',
        );
      }

      return ToolResult.success(result.toJson());
    } catch (e) {
      return ToolResult.failure('Vision analysis error: $e', errorCode: 'VISION_EXCEPTION');
    }
  }
}
