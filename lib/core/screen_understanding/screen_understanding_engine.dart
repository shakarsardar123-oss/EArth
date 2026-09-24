/// Concrete implementation of [ScreenUnderstandingService].
///
/// Delegates vision analysis to the existing [VisionService],
/// adds a structured screen-analysis prompt, parses the JSON
/// response into [ScreenRepresentation], and implements
/// throttling, deduplication, latest-frame processing,
/// concurrent protection, and cancellation.
library;

import 'dart:async';
import 'dart:convert';

import '../../services/vision/vision_service.dart';
import '../../domain/entities/vision/vision_entities.dart';
import '../errors/failures.dart';
import '../errors/result.dart';
import '../screen_capture/screen_capture_result.dart';
import 'screen_understanding_result.dart';
import 'screen_understanding_service.dart';
import 'screen_understanding_state.dart';

// ── Constants ───────────────────────────────────────────────────

/// Minimum interval between successive analysis calls.
const _minAnalysisInterval = Duration(milliseconds: 500);

/// Structured prompt sent to the vision model for screen analysis.
const _screenAnalysisPrompt = '''
You are a mobile screen analysis assistant. Analyze this screenshot of a mobile app.

Identify ALL of the following and respond in JSON:

1. **text_items**: Every visible piece of text. For each, provide:
   - "text": the visible text
   - "text_type": one of ["body", "heading", "button", "link", "caption", "menu_label", "placeholder", "notification", "tooltip", "other"]
   - "bounding_box": {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0} (normalized 0-1)
   - "confidence": 0.0-1.0
   - "language": detected language code (e.g. "en", "ku", "ar") if identifiable, or null

2. **ui_elements**: Every interactive or structural UI element. For each, provide:
   - "type": one of ["button", "text_field", "checkbox", "radio_button", "dropdown", "slider", "switch", "icon", "image", "card", "list_item", "tab", "navigation_bar", "toolbar", "dialog", "fab", "chip", "progress_indicator", "scroll_view", "other"]
   - "label": accessible label or visible text, or null
   - "bounding_box": {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0} (normalized 0-1)
   - "confidence": 0.0-1.0
   - "is_enabled": true/false
   - "is_selected": true/false

3. **regions**: Named screen layout regions. For each, provide:
   - "type": one of ["status_bar", "app_bar", "content", "bottom_navigation", "fab_region", "drawer", "dialog_overlay", "snackbar", "keyboard", "tab_bar", "search_bar", "other"]
   - "bounding_box": {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0} (normalized 0-1)
   - "confidence": 0.0-1.0

4. **metadata": Screen-level information:
   - "app_name": name of the app if identifiable, or null
   - "app_package": package/bundle ID if identifiable, or null
   - "overall_confidence": 0.0-1.0

Respond ONLY with valid JSON in this exact format:
{
  "text_items": [...],
  "ui_elements": [...],
  "regions": [...],
  "metadata": {
    "app_name": null,
    "app_package": null,
    "overall_confidence": 0.9
  }
}
''';

/// Hash of an empty byte list (for deduplication baseline).
const _emptyBytesHash = 0;

// ── Engine ──────────────────────────────────────────────────────

/// Concrete [ScreenUnderstandingService] that delegates to [VisionService].
class ScreenUnderstandingEngine implements ScreenUnderstandingService {
  ScreenUnderstandingEngine({
    required VisionService visionService,
    Duration minAnalysisInterval = _minAnalysisInterval,
  })  : _visionService = visionService,
        _minInterval = minAnalysisInterval;

  final VisionService _visionService;
  final Duration _minInterval;

  // ── Mutable state ───────────────────────────────────────
  ScreenUnderstandingState _state = const ScreenUnderstandingState();
  final StreamController<ScreenUnderstandingState> _stateController =
      StreamController<ScreenUnderstandingState>.broadcast();

  /// Lock to prevent concurrent analysis.
  bool _analysisLock = false;

  /// Timestamp of the last analysis start.
  DateTime? _lastAnalysisTime;

  /// Hash of the last analyzed frame (for deduplication).
  int _lastFrameHash = _emptyBytesHash;

  /// Cancellation flag for the current analysis.
  bool _cancelRequested = false;

  /// Subscription for continuous analysis stream.
  StreamSubscription<CapturedFrame>? _continuousSubscription;

  /// Completer for the current continuous analysis result.
  Completer<Result<ScreenRepresentation, ScreenUnderstandingFailure>>?
      _continuousCompleter;

  // ── Public API ─────────────────────────────────────────

  @override
  ScreenUnderstandingState get state => _state;

  @override
  Stream<ScreenUnderstandingState> get stateStream => _stateController.stream;

  @override
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      analyzeFrame(CapturedFrame frame) async {
    // ── Check cancellation ──
    if (_cancelRequested) {
      return _reject(
        const ScreenUnderstandingFailure(
          message: 'Analysis was cancelled',
          phase: ScreenUnderstandingPhase.cancelled,
        ),
      );
    }

    // ── Concurrent protection ──
    if (_analysisLock) {
      _bumpThrottled();
      return _reject(
        const ScreenUnderstandingFailure(
          message: 'Analysis already in progress',
          phase: ScreenUnderstandingPhase.concurrentConflict,
        ),
      );
    }

    // ── Throttle check ──
    if (_lastAnalysisTime != null) {
      final elapsed = DateTime.now().difference(_lastAnalysisTime!);
      if (elapsed < _minInterval) {
        _bumpThrottled();
        return _reject(
          const ScreenUnderstandingFailure(
            message: 'Analysis throttled — too soon after previous analysis',
            phase: ScreenUnderstandingPhase.throttled,
          ),
        );
      }
    }

    // ── Deduplication check ──
    final frameHash = _computeFrameHash(frame);
    if (frameHash == _lastFrameHash && _state.hasResult) {
      _bumpDeduplicated();
      // Return the existing representation as a success.
      final existing = _state.representation;
      if (existing != null) {
        return Result.success(existing);
      }
    }

    // ── Acquire lock and run analysis ──
    _analysisLock = true;
    _lastAnalysisTime = DateTime.now();
    _cancelRequested = false;
    _emit(_state.copyWith(status: ScreenUnderstandingStatus.analyzing));

    try {
      final result = await _performAnalysis(frame);

      // Check if cancelled during analysis.
      if (_cancelRequested) {
        _emit(_state.copyWith(
          status: ScreenUnderstandingStatus.cancelled,
        ));
        return _fail(
          const ScreenUnderstandingFailure(
            message: 'Analysis was cancelled during processing',
            phase: ScreenUnderstandingPhase.cancelled,
          ),
        );
      }

      return result.fold(
        onSuccess: (representation) {
          _lastFrameHash = frameHash;
          final hasContent = representation.hasContent;
          _emit(_state.copyWith(
            status: hasContent
                ? ScreenUnderstandingStatus.success
                : ScreenUnderstandingStatus.noContent,
            representation: representation,
            lastAnalysisTimestamp: representation.metadata.timestamp,
            analysisCount: _state.analysisCount + 1,
          ));
          return Result.success(representation);
        },
        onFailure: (failure) {
          _emit(_state.copyWith(
            status: ScreenUnderstandingStatus.error,
            errorMessage: failure.message,
          ));
          return Result.failure(failure);
        },
      );
    } finally {
      _analysisLock = false;
    }
  }

  @override
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      analyzeLatestFrame(Stream<CapturedFrame> frameStream) async {
    // ── Concurrent protection ──
    if (_analysisLock) {
      return _fail(
        const ScreenUnderstandingFailure(
          message: 'Analysis already in progress',
          phase: ScreenUnderstandingPhase.concurrentConflict,
        ),
      );
    }

    _continuousCompleter = Completer<
        Result<ScreenRepresentation, ScreenUnderstandingFailure>>();

    // Latest-frame-wins: only process the most recent frame.
    CapturedFrame? latestFrame;

    _continuousSubscription = frameStream.listen(
      (frame) {
        latestFrame = frame; // Always keep the latest.
      },
      onDone: () {
        if (latestFrame != null) {
          // Analyze the latest frame collected from the stream.
          analyzeFrame(latestFrame!).then((result) {
            if (!_continuousCompleter!.isCompleted) {
              _continuousCompleter!.complete(result);
            }
          });
        } else {
          if (!_continuousCompleter!.isCompleted) {
            _continuousCompleter!.complete(_reject(
              const ScreenUnderstandingFailure(
                message: 'Stream ended without producing a frame',
                phase: ScreenUnderstandingPhase.noFrame,
              ),
            ));
          }
        }
      },
      onError: (Object error) {
        if (!_continuousCompleter!.isCompleted) {
          _continuousCompleter!.complete(_reject(
            ScreenUnderstandingFailure(
              message: 'Stream error: $error',
              phase: ScreenUnderstandingPhase.noFrame,
            ),
          ));
        }
      },
    );

    return _continuousCompleter!.future;
  }

  @override
  void cancel() {
    _cancelRequested = true;
    _continuousSubscription?.cancel();
    _continuousSubscription = null;

    if (_continuousCompleter != null &&
        !_continuousCompleter!.isCompleted) {
      _continuousCompleter!.complete(_reject(
        const ScreenUnderstandingFailure(
          message: 'Analysis cancelled by user',
          phase: ScreenUnderstandingPhase.cancelled,
        ),
      ));
    }

    _emit(_state.copyWith(
      status: ScreenUnderstandingStatus.cancelled,
    ));
  }

  @override
  Future<void> dispose() async {
    cancel();
    await _stateController.close();
    await _continuousSubscription?.cancel();
    _continuousSubscription = null;
  }

  // ── Internal helpers ───────────────────────────────────

  /// Core analysis: convert frame → base64, call vision, parse result.
  Future<Result<ScreenRepresentation, ScreenUnderstandingFailure>>
      _performAnalysis(CapturedFrame frame) async {
    // ── Step 1: Convert frame bytes to base64 ──
    final base64Result = _frameToBase64(frame);
    if (base64Result == null) {
      return _fail(
        const ScreenUnderstandingFailure(
          message: 'Failed to convert frame to base64',
          phase: ScreenUnderstandingPhase.frameConversion,
        ),
      );
    }

    // ── Step 2: Call VisionService.analyzeImage with structured prompt ──
    VisionResult visionResult;
    try {
      visionResult = await _visionService.analyzeImage(
        imageBase64: base64Result,
        prompt: _screenAnalysisPrompt,
      );
    } catch (e) {
      return _fail(
        ScreenUnderstandingFailure(
          message: 'Vision service error: $e',
          phase: ScreenUnderstandingPhase.visionAnalysis,
        ),
      );
    }

    // ── Step 3: Check for vision failure ──
    if (!visionResult.isSuccess) {
      return _fail(
        ScreenUnderstandingFailure(
          message: visionResult.errorMessage ?? 'Vision analysis failed',
          phase: ScreenUnderstandingPhase.visionAnalysis,
        ),
      );
    }

    // ── Step 4: Parse the VisionResult into ScreenRepresentation ──
    return _parseVisionResultToScreenRepresentation(visionResult, frame);
  }

  /// Convert [CapturedFrame.bytes] (Uint8ListSafe) to base64 string.
  String? _frameToBase64(CapturedFrame frame) {
    try {
      final byteList = frame.bytes.toList();
      return base64Encode(byteList);
    } catch (_) {
      return null;
    }
  }

  /// Parse [VisionResult] into [ScreenRepresentation].
  ///
  /// Tries to parse the raw JSON from the vision response.
  /// Falls back to extracting text/elements from VisionResult targets
  /// if the structured JSON is unavailable.
  Result<ScreenRepresentation, ScreenUnderstandingFailure>
      _parseVisionResultToScreenRepresentation(
    VisionResult visionResult,
    CapturedFrame frame,
  ) {
    try {
      // Attempt structured JSON parse from the raw response.
      final rawResponse = visionResult.rawResponse;
      if (rawResponse != null) {
        return _parseRawJsonResponse(rawResponse, frame, visionResult);
      }

      // Fallback: build ScreenRepresentation from VisionResult fields.
      return _buildFromVisionResult(visionResult, frame);
    } catch (e) {
      return _fail(
        ScreenUnderstandingFailure(
          message: 'Failed to parse vision response: $e',
          phase: ScreenUnderstandingPhase.responseParsing,
        ),
      );
    }
  }

  /// Try to parse the structured screen-analysis JSON from the raw response.
    Result<ScreenRepresentation, ScreenUnderstandingFailure>
        _parseRawJsonResponse(
      Map<String, dynamic> rawResponse,
      CapturedFrame frame,
      VisionResult visionResult,
    ) {
      try {
        String? content;

        final choices = rawResponse['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map<String, dynamic>) {
            final message = first['message'];
            if (message is Map<String, dynamic>) {
              final value = message['content'];
              if (value is String && value.trim().isNotEmpty) {
                content = value;
              }
            }
          }
        }

        if (content == null) {
          final candidates = rawResponse['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            final first = candidates.first;
            if (first is Map<String, dynamic>) {
              final candidateContent = first['content'];
              if (candidateContent is Map<String, dynamic>) {
                final parts = candidateContent['parts'];
                if (parts is List) {
                  final buffer = StringBuffer();

                  for (final part in parts) {
                    if (part is Map<String, dynamic>) {
                      final value = part['text'];
                      if (value is String && value.isNotEmpty) {
                        buffer.write(value);
                      }
                    }
                  }

                  final combined = buffer.toString().trim();
                  if (combined.isNotEmpty) {
                    content = combined;
                  }
                }
              }
            }
          }
        }

        if (content == null || content!.trim().isEmpty) {
          return _buildFromVisionFields(rawResponse, frame);
        }

        var jsonStr = content!.trim();

        final fenceMatch = RegExp(
          r'```(?:json)?\s*\n?([\s\S]*?)\n?```',
        ).firstMatch(jsonStr);

        if (fenceMatch != null) {
          jsonStr = fenceMatch.group(1)?.trim() ?? jsonStr;
        }

        final decoded = jsonDecode(jsonStr);

        if (decoded is! Map<String, dynamic>) {
          return _buildFromVisionFields(rawResponse, frame);
        }

        final parsed = decoded;

        final textItems = <ScreenTextItem>[];
        final textList = parsed['text_items'];

        if (textList is List) {
          for (final item in textList) {
            try {
              if (item is! Map<String, dynamic>) continue;

              textItems.add(
                ScreenTextItem(
                  text: item['text'] is String
                      ? item['text'] as String
                      : '',
                  textType: _parseTextType(
                    item['text_type'] is String
                        ? item['text_type'] as String
                        : null,
                  ),
                  boundingBox: _parseBBox(
                    item['bounding_box'] is Map<String, dynamic>
                        ? item['bounding_box'] as Map<String, dynamic>
                        : null,
                  ),
                  confidence: _safeConfidence(
                    item['confidence'],
                    0.8,
                  ),
                  language: item['language'] is String
                      ? item['language'] as String
                      : null,
                ),
              );
            } catch (_) {}
          }
        }

        final uiElements = <UIElement>[];
        final uiList = parsed['ui_elements'];

        if (uiList is List) {
          for (final item in uiList) {
            try {
              if (item is! Map<String, dynamic>) continue;

              uiElements.add(
                UIElement(
                  type: _parseUIElementType(
                    item['type'] is String
                        ? item['type'] as String
                        : null,
                  ),
                  label: item['label'] is String
                      ? item['label'] as String
                      : null,
                  boundingBox: _parseBBox(
                    item['bounding_box'] is Map<String, dynamic>
                        ? item['bounding_box'] as Map<String, dynamic>
                        : null,
                  ),
                  confidence: _safeConfidence(
                    item['confidence'],
                    0.8,
                  ),
                  isEnabled: item['is_enabled'] is bool
                      ? item['is_enabled'] as bool
                      : true,
                  isSelected: item['is_selected'] is bool
                      ? item['is_selected'] as bool
                      : false,
                ),
              );
            } catch (_) {}
          }
        }

        final regions = <ScreenRegion>[];
        final regionList = parsed['regions'];

        if (regionList is List) {
          for (final item in regionList) {
            try {
              if (item is! Map<String, dynamic>) continue;

              regions.add(
                ScreenRegion(
                  type: _parseRegionType(
                    item['type'] is String
                        ? item['type'] as String
                        : null,
                  ),
                  boundingBox: _parseBBox(
                    item['bounding_box'] is Map<String, dynamic>
                        ? item['bounding_box'] as Map<String, dynamic>
                        : null,
                  ),
                  confidence: _safeConfidence(
                    item['confidence'],
                    0.8,
                  ),
                ),
              );
            } catch (_) {}
          }
        }

        final metaMap = parsed['metadata'] is Map<String, dynamic>
            ? parsed['metadata'] as Map<String, dynamic>
            : null;

        final metadata = ScreenMetadata(
          timestamp: frame.timestamp,
          width: frame.width,
          height: frame.height,
          rotation: frame.rotation,
          appName: (metaMap?['app_name'] as Object?) is String
              ? metaMap!['app_name'] as String
              : null,
          appPackage: (metaMap?['app_package'] as Object?) is String
              ? metaMap!['app_package'] as String
              : null,
          overallConfidence: _safeConfidence(
            metaMap?['overall_confidence'],
            0.8,
          ),
          modelUsed: visionResult.modelUsed,
          processingTimeMs: visionResult.processingTimeMs,
        );

        return Result.success(
          ScreenRepresentation(
            metadata: metadata,
            textItems: textItems,
            uiElements: uiElements,
            regions: regions,
          ),
        );
      } catch (_) {
        return _buildFromVisionFields(rawResponse, frame);
      }
    }

    double _safeConfidence(dynamic value, double fallback) {
      if (value is! num) return fallback;

      final result = value.toDouble();

      if (!result.isFinite || result < 0.0 || result > 1.0) {
        return fallback;
      }

      return result;
    }

    double? _finiteDouble(dynamic value) {
      if (value is! num) return null;

      final result = value.toDouble();

      return result.isFinite ? result : null;
    }

    TextBoundingBox _parseBBox(Map<String, dynamic>? map) {
      if (map == null) {
        return const TextBoundingBox(
          x: 0,
          y: 0,
          width: 1,
          height: 1,
        );
      }

      final x = _finiteDouble(map['x']);
      final y = _finiteDouble(map['y']);
      final width = _finiteDouble(map['width']);
      final height = _finiteDouble(map['height']);

      if (x == null ||
          y == null ||
          width == null ||
          height == null ||
          x < 0 ||
          y < 0 ||
          width <= 0 ||
          height <= 0 ||
          x > 1 ||
          y > 1 ||
          width > 1 ||
          height > 1 ||
          x + width > 1 ||
          y + height > 1) {
        return const TextBoundingBox(
          x: 0,
          y: 0,
          width: 1,
          height: 1,
        );
      }

      return TextBoundingBox(
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }


  /// Fallback: build a ScreenRepresentation from VisionResult's own fields
  /// when the structured JSON is not available.
  Result<ScreenRepresentation, ScreenUnderstandingFailure>
      _buildFromVisionResult(
    VisionResult visionResult,
    CapturedFrame frame,
  ) {
    // Convert VisionTargets to text items and UI elements.
    final textItems = <ScreenTextItem>[];
    final uiElements = <UIElement>[];
    final regions = <ScreenRegion>[];

    for (final target in visionResult.targets) {

      final bboxForTarget = target.boundingBox != null
          ? TextBoundingBox(
              x: target.boundingBox!.x,
              y: target.boundingBox!.y,
              width: target.boundingBox!.width,
              height: target.boundingBox!.height,
            )
          : const TextBoundingBox(x: 0, y: 0, width: 1, height: 1);

      if (target.type == VisionTargetType.text) {
        textItems.add(ScreenTextItem(
          text: target.label,
          boundingBox: bboxForTarget,
          confidence: target.confidence ?? 0.8,
          language: null,
        ));
      } else {
        uiElements.add(UIElement(
          type: _mapVisionTargetType(target.type),
          label: target.label,
          boundingBox: bboxForTarget,
          confidence: target.confidence ?? 0.8,
        ));
      }
    }

    // Add OCR text as a single text item if present.
    if (visionResult.ocrText != null && visionResult.ocrText!.isNotEmpty) {
      textItems.insert(
        0,
        ScreenTextItem(
          text: visionResult.ocrText!,
          boundingBox: const TextBoundingBox(x: 0, y: 0, width: 1, height: 1),
          confidence: 0.7,
        ),
      );
    }

    // Default content region.
    regions.add(const ScreenRegion(
      type: ScreenRegionType.content,
      boundingBox: TextBoundingBox(x: 0, y: 0, width: 1, height: 1),
      confidence: 0.5,
    ));

    final metadata = ScreenMetadata(
      timestamp: frame.timestamp,
      width: frame.width,
      height: frame.height,
      rotation: frame.rotation,
      overallConfidence: 0.6,
      modelUsed: visionResult.modelUsed,
      processingTimeMs: visionResult.processingTimeMs,
    );

    return Result.success(ScreenRepresentation(
      metadata: metadata,
      textItems: textItems,
      uiElements: uiElements,
      regions: regions,
    ));
  }

  /// Fallback when raw response exists but content is missing/empty.
  Result<ScreenRepresentation, ScreenUnderstandingFailure>
      _buildFromVisionFields(
    Map<String, dynamic> rawResponse,
    CapturedFrame frame,
  ) {
    // Minimal representation with just metadata.
    final metadata = ScreenMetadata(
      timestamp: frame.timestamp,
      width: frame.width,
      height: frame.height,
      rotation: frame.rotation,
      overallConfidence: 0.3,
    );

    return Result.success(ScreenRepresentation(
      metadata: metadata,
      textItems: const [],
      uiElements: const [],
      regions: const [],
    ));
  }

  /// Map [VisionTargetType] to [UIElementType].
  UIElementType _mapVisionTargetType(VisionTargetType type) {
    switch (type) {
      case VisionTargetType.text:
        return UIElementType.other;
      case VisionTargetType.person:
        return UIElementType.other;
      case VisionTargetType.object:
        return UIElementType.other;
      case VisionTargetType.sceneElement:
        return UIElementType.card;
      case VisionTargetType.animal:
        return UIElementType.image;
      case VisionTargetType.vehicle:
        return UIElementType.image;
      case VisionTargetType.food:
        return UIElementType.image;
      case VisionTargetType.poseLandmark:
        return UIElementType.other;
      case VisionTargetType.other:
        return UIElementType.other;
    }
  }

  /// Parse a text type string into [TextType].
  TextType _parseTextType(String? value) {
    if (value == null) return TextType.other;
    return TextType.values.firstWhere(
      (e) => e.name == value || e.name == _snakeToCamel(value),
      orElse: () => TextType.other,
    );
  }

  /// Parse a UI element type string into [UIElementType].
  UIElementType _parseUIElementType(String? value) {
    if (value == null) return UIElementType.other;
    return UIElementType.values.firstWhere(
      (e) => e.name == value || e.name == _snakeToCamel(value),
      orElse: () => UIElementType.other,
    );
  }

  /// Parse a screen region type string into [ScreenRegionType].
  ScreenRegionType _parseRegionType(String? value) {
    if (value == null) return ScreenRegionType.other;
    return ScreenRegionType.values.firstWhere(
      (e) => e.name == value || e.name == _snakeToCamel(value),
      orElse: () => ScreenRegionType.other,
    );
  }

  /// Convert snake_case to camelCase for enum matching.
  String _snakeToCamel(String value) {
    final parts = value.split('_');
    if (parts.length == 1) return value;
    return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }


  /// Compute a simple hash of the frame bytes for deduplication.
  int _computeFrameHash(CapturedFrame frame) {
    final bytes = frame.bytes;
    if (bytes.length == 0) return _emptyBytesHash;
    // Simple hash: XOR of sampled byte positions.
    var hash = 0;
    final step = bytes.length > 1000 ? bytes.length ~/ 1000 : 1;
    for (var i = 0; i < bytes.length; i += step) {
      hash ^= bytes[i] << (i % 32);
    }
    return hash;
  }

  /// Emit a new state to the stream.
  void _emit(ScreenUnderstandingState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Create a failure result and set state to error.
  ///
  /// Use this for genuine errors (frame conversion, vision,
  /// parsing). Do NOT use for throttled/concurrent/cancelled
  /// rejections — use [_reject] instead.
  Result<ScreenRepresentation, ScreenUnderstandingFailure> _fail(
    ScreenUnderstandingFailure failure,
  ) {
    _emit(_state.copyWith(
      status: ScreenUnderstandingStatus.error,
      errorMessage: failure.message,
    ));
    return Result.failure(failure);
  }

  /// Create a failure result WITHOUT changing state to error.
  ///
  /// Use this for throttled/concurrent/cancelled rejections
  /// where the status should remain as-is (e.g. idle, success)
  /// rather than transitioning to error.
  Result<ScreenRepresentation, ScreenUnderstandingFailure> _reject(
    ScreenUnderstandingFailure failure,
  ) {
    // No state change — the caller may bump counters separately.
    return Result.failure(failure);
  }

  /// Increment the throttled counter.
  void _bumpThrottled() {
    _emit(_state.copyWith(
      throttledCount: _state.throttledCount + 1,
    ));
  }

  /// Increment the deduplicated counter.
  void _bumpDeduplicated() {
    _emit(_state.copyWith(
      deduplicatedCount: _state.deduplicatedCount + 1,
    ));
  }
}
