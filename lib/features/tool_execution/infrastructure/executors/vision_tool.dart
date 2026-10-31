/// vision_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// VisionTool — handles visual analysis interactions.
/// Category: intelligence
/// Risk: medium (image analysis, privacy concerns)
/// Offline: no (needs AI service)
/// Voice-safe: no (requires visual interaction)
///
/// FIX: gallery action now uses real image_picker to pick an image
/// from the device gallery, then returns the image path for analysis
/// by the VisionService pipeline.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

// --- VisionToolCache (preserved from original) ---
enum VisionCacheType {
  objectRecognition,
  textExtraction,
  sceneDescription,
}

class VisionCacheEntry {
  final String imagePath;
  final VisionCacheType type;
  final String result;
  final DateTime timestamp;
  VisionCacheEntry({
    required this.imagePath,
    required this.type,
    required this.result,
    required this.timestamp,
  });
}

class VisionToolCache {
  static final VisionToolCache _instance = VisionToolCache._();
  static VisionToolCache get instance => _instance;
  VisionToolCache._();

  final Map<String, VisionCacheEntry> _cache = {};

  void put(String key, VisionCacheEntry entry) => _cache[key] = entry;
  VisionCacheEntry? get(String key) => _cache[key];
  void clear() => _cache.clear();
}

// --- VisionTool ---
class VisionTool extends Tool {
  @override
  String get id => 'aura.tool.vision';

  @override
  String get name => 'Vision';

  @override
  ToolCategory get category => ToolCategory.intelligence;

  @override
  String get description =>
      'Analyze images, recognize objects, read text, and describe scenes';

  @override
  String get version => '1.1.0';

  @override
  List<String> get requiredPermissions => [
        'vision.camera',
        'vision.gallery',
        'vision.analysis',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.medium;

  @override
  bool get requiresConfirmation => true;

  @override
  bool get supportsOffline => false;

  @override
  bool get isVoiceSafe => false;

  @override
  int get defaultTimeoutMs => 30000;

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
          errorMessage: 'Invalid vision input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'status';

      switch (action) {
        case 'gallery':
          return await _pickFromGallery();

        case 'camera':
          return await _pickFromCamera();

        case 'analyze':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'analyze',
              'message': 'Image queued for analysis via VisionService pipeline',
              'imagePath': input.sanitizedParams['imagePath'],
            },
          );

        case 'status':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'status',
              'status': 'available',
              'services': ['object', 'text', 'scene', 'locate'],
            },
          );

        default:
          return ToolOutput.failure(
            toolId: id,
            errorMessage: 'Unknown vision action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Vision tool error: ${_sanitizeError(e)}',
      );
    } finally {
      _isExecuting = false;
    }
  }

  /// Picks an image from the device gallery using image_picker.
  ///
  /// The image_picker package works at the platform level — it
  /// presents the native gallery picker UI without needing an
  /// explicit Flutter navigator context.
  Future<ToolOutput> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (picked == null) {
        // User cancelled the picker
        return ToolOutput.cancelled(
          toolId: id,
          message: 'User cancelled gallery picker',
        );
      }

      // Check the file exists
      final file = File(picked.path);
      if (!await file.exists()) {
        return ToolOutput.failure(
          toolId: id,
          errorMessage: 'Selected image file not found',
        );
      }

      // Cache the result
      VisionToolCache.instance.put(
        'gallery_last',
        VisionCacheEntry(
          imagePath: picked.path,
          type: VisionCacheType.objectRecognition,
          result: '', // Will be filled by VisionService analysis
          timestamp: DateTime.now(),
        ),
      );

      return ToolOutput.success(
        toolId: id,
        data: {
          'action': 'gallery',
          'imagePath': picked.path,
          'mimeType': picked.mimeType ?? 'image/jpeg',
          'sizeBytes': await file.length(),
        },
      );
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Gallery picker failed: ${_sanitizeError(e)}',
        errorCode: 'GALLERY_ERROR',
      );
    }
  }

  /// Captures an image from the camera using image_picker.
  Future<ToolOutput> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? captured = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (captured == null) {
        return ToolOutput.cancelled(
          toolId: id,
          message: 'User cancelled camera capture',
        );
      }

      final file = File(captured.path);
      if (!await file.exists()) {
        return ToolOutput.failure(
          toolId: id,
          errorMessage: 'Captured image file not found',
        );
      }

      // Cache the result
      VisionToolCache.instance.put(
        'camera_last',
        VisionCacheEntry(
          imagePath: captured.path,
          type: VisionCacheType.objectRecognition,
          result: '',
          timestamp: DateTime.now(),
        ),
      );

      return ToolOutput.success(
        toolId: id,
        data: {
          'action': 'camera',
          'imagePath': captured.path,
          'mimeType': captured.mimeType ?? 'image/jpeg',
          'sizeBytes': await file.length(),
        },
      );
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Camera capture failed: ${_sanitizeError(e)}',
        errorCode: 'CAMERA_ERROR',
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
  String describe() => 'ئامرازێکی بینین بۆ شیکردنەوەی وێنە'; // Kurdish Sorani

  @override
  void cancel() {}

  String _sanitizeError(Object error) {
    final msg = error.toString();
    if (msg.length > 200) return msg.substring(0, 200);
    return msg;
  }

  static const _validActions = ['gallery', 'camera', 'analyze', 'status'];
}
