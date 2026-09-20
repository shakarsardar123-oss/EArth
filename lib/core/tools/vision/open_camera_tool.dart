import 'package:camera/camera.dart' as cam;

import '../../../services/camera/vision_camera_service.dart';
import '../tool.dart';
import '../tool_definition.dart';
import '../tool_arguments.dart';
import '../tool_result.dart';
import '../tool_permission.dart';
import '../../../core/errors/result.dart';

/// Tool to open the live vision camera.
///
/// Activates the camera preview for the vision feature.
/// Used by the agent when the user asks to see through the camera.
class OpenCameraTool extends Tool {
  OpenCameraTool(this._cameraService);

  final VisionCameraService _cameraService;

  @override
  ToolDefinition get definition => const ToolDefinition(
        name: 'open_camera',
        description:
            'Open the live vision camera. Activates the camera preview for AI-powered visual analysis.',
        category: 'vision',
        parameters: [
          ToolArgumentDef(
            name: 'lens',
            type: 'string',
            description: 'Camera lens direction',
            isRequired: false,
            defaultValue: 'back',
            enumValues: ['back', 'front'],
          ),
        ],
        permissionRequirements: [
          ToolPermissionRequirement(
            permission: ToolPermission.camera,
            isRequired: true,
            rationale: 'Camera access is required to open the live vision camera',
          ),
        ],
        tags: ['vision', 'camera'],
      );

  @override
  Future<ToolResult> execute(ToolArguments args) async {
    final lens = args.getOrElse<String>('lens', 'back');
    final direction = lens == 'front'
        ? cam.CameraLensDirection.front
        : cam.CameraLensDirection.back;

    // Really initialize the camera through the existing vision camera service.
    final cam.CameraController? controller;
    try {
      controller = await _cameraService.initialize(lensDirection: direction);
    } catch (e) {
      return ToolResult.failure(
        'Failed to open the camera: $e',
        errorCode: 'CAMERA_OPEN_FAILED',
      );
    }

    if (controller == null || !_cameraService.isInitialized) {
      return const ToolResult.failure(
        'Camera could not be opened. No usable camera was initialized '
        '(device may have no camera, or access was refused).',
        errorCode: 'CAMERA_UNAVAILABLE',
      );
    }

    final activeLens = _cameraService.currentLensDirection.name;
    return ToolResult.success({
      'action': 'open_camera',
      'lens': activeLens,
      'requested_lens': lens,
      'message': 'Camera opened ($activeLens lens) for vision',
    });
  }
}
