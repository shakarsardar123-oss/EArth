/// media_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// MediaTool — handles media file management and playback.
/// Category: media
/// Risk: medium (storage access, media playback)
/// Offline: partial (local media playback works offline)
/// Voice-safe: yes (basic commands)
///
/// FIX: library action now uses real file_picker to pick media files
/// from the device storage. Also added toolId to all ToolOutput calls.
library;

import 'package:file_picker/file_picker.dart';

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class MediaTool extends Tool {
  @override
  String get id => 'aura.tool.media';

  @override
  String get name => 'Media';

  @override
  ToolCategory get category => ToolCategory.media;

  @override
  String get description =>
      'Manage and control media files including audio, video, and images';

  @override
  String get version => '1.1.0';

  @override
  List<String> get requiredPermissions => [
        'media.storage',
        'media.audio',
        'media.video',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.medium;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get supportsOffline => true;

  @override
  bool get isVoiceSafe => true;

  @override
  int get defaultTimeoutMs => 10000;

  bool _isExecuting = false;

  @override
  bool get isExecuting => _isExecuting;

  @override
  Future<ToolOutput> execute(ToolInput input, ToolExecutionContext context) async {
    _isExecuting = true;
    try {
      context.throwIfCancelled();
      if (!input.isValid) {
        return ToolOutput.failure(
          toolId: id,
          errorMessage: 'Invalid media input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'status';

      switch (action) {
        case 'play':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'play',
              'source': input.sanitizedParams['source'] ?? 'unknown',
              'status': 'playing',
            },
          );

        case 'pause':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'pause',
              'status': 'paused',
            },
          );

        case 'stop':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'stop',
              'status': 'stopped',
            },
          );

        case 'library':
          return await _pickFromLibrary();

        case 'volume':
          final level = input.sanitizedParams['level'] as num?;
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'volume',
              'level': level ?? 50,
              'status': 'adjusted',
            },
          );

        case 'status':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'status',
              'status': 'available',
              'services': ['play', 'pause', 'stop', 'library', 'volume'],
            },
          );

        default:
          return ToolOutput.failure(
            toolId: id,
            errorMessage: 'Unknown media action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Media tool error: ${_sanitizeError(e)}',
      );
    } finally {
      _isExecuting = false;
    }
  }

  /// Picks media files from the device using file_picker.
  ///
  /// file_picker works at the platform level and shows the native
  /// file chooser without needing a Flutter navigator context.
  Future<ToolOutput> _pickFromLibrary() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled the picker
        return ToolOutput.cancelled(
          toolId: id,
          message: 'User cancelled file picker',
        );
      }

      final pickedFile = result.files.first;
      final filePath = pickedFile.path;

      if (filePath == null || filePath.isEmpty) {
        return ToolOutput.failure(
          toolId: id,
          errorMessage: 'Selected file path is unavailable',
        );
      }

      return ToolOutput.success(
        toolId: id,
        data: {
          'action': 'library',
          'filePath': filePath,
          'fileName': pickedFile.name,
          'fileSize': pickedFile.size,
          'fileExtension': pickedFile.extension ?? '',
        },
      );
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'File picker failed: ${_sanitizeError(e)}',
        errorCode: 'FILE_PICKER_ERROR',
      );
    }
  }

  @override
  ToolInput validate(Map<String, dynamic> params) {
    final action = params['action'] as String?;
    if (action == null || !_validActions.contains(action)) {
      return ToolInput.invalid(
        toolId: id,
        rawParams: params,
        field: 'action',
        message: 'Valid actions: ${_validActions.join(", ")}',
      );
    }
    return ToolInput.valid(
      toolId: id,
      params: Map<String, dynamic>.from(params),
    );
  }

  @override
  String describe() => 'ئامرازێکی میدیا بۆ بەڕێوەبردنی فایلی میدیا'; // Kurdish Sorani

  @override
  void cancel() {}

  String _sanitizeError(Object error) {
    final msg = error.toString();
    if (msg.length > 200) return msg.substring(0, 200);
    return msg;
  }

  static const _validActions = ['play', 'pause', 'stop', 'library', 'volume', 'status'];
}
