import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../tool_permission.dart';
import '../../../services/vision/vision_service.dart';
import '../../../core/errors/result.dart';

/// Tool to read/OCR text from an image using AI vision.
///
/// Extracts visible text, returns content and location info
class ReadTextTool extends Tool {
  final VisionService _visionService;

  ReadTextTool(this._visionService);

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'read_text',
        description:
            'Read and extract text from an image (OCR). Returns recognized text content and locations.',
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
            name: 'language_hint',
            type: 'string',
            description: 'Optional language hint for text recognition (e.g. "en", "ku", "ar")',
            isRequired: false,
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.camera,
            isRequired: true,
            rationale: 'Text reading requires camera access',
          ),
          ToolPermissionRequirement(
            permission: ToolPermission.network,
            isRequired: true,
            rationale: 'AI text recognition requires internet to reach the vision API',
          ),
        ],
        tags: ['vision', 'camera', 'ai', 'ocr', 'text'],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final imageBase64 = args.get<String>('image_base64');
    final languageHint = args.getString('language_hint');

    if (imageBase64.isEmpty) {
      return const ToolResult.failure('image_base64 cannot be empty');
    }

    try {
      final result = await _visionService.readText(
        imageBase64: imageBase64,
        language: languageHint,
      );

      if (!result.isSuccess) {
        return ToolResult.failure(
          result.errorMessage ?? 'Text reading failed',
          errorCode: 'OCR_ERROR',
        );
      }

      return ToolResult.success(result.toJson());
    } catch (e) {
      return ToolResult.failure('Read text error: $e', errorCode: 'VISION_EXCEPTION');
    }
  }
}
