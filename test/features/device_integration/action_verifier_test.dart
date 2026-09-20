/// Tests for ActionVerifier.
/// Covers: 5 verification methods (pixelChange, targetDisappear,
/// targetAppear, textMatch, none), missing params failures.
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/application/action_verifier.dart';
import 'package:aura_assistant/features/device_integration/domain/entities/device_action.dart';
import 'package:aura_assistant/features/device_integration/domain/models/device_integration_failure.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/services/screen_capture_service.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/services/screen_understanding_engine.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/services/screen_search_service.dart';
import 'package:aura_assistant/core/errors/result.dart';

/// Fake ScreenCaptureService.
class FakeScreenCaptureService implements ScreenCaptureService {
  bool shouldThrow = false;
  CapturedFrame? _frame;

  void setFrame(CapturedFrame frame) => _frame = frame;

  @override
  Future<CapturedFrame> capture() async {
    if (shouldThrow) throw Exception('Capture failed');
    if (_frame != null) return _frame!;
    return CapturedFrame(
      imageBytes: Uint8List(100),
      width: 1080,
      height: 1920,
      timestamp: DateTime.now(),
    );
  }
}

/// Fake ScreenUnderstandingEngine.
class FakeScreenUnderstandingEngine implements ScreenUnderstandingEngine {
  bool shouldThrow = false;
  ScreenRepresentation? _representation;

  void setRepresentation(ScreenRepresentation r) => _representation = r;

  @override
  Future<ScreenRepresentation> analyze(CapturedFrame frame) async {
    if (shouldThrow) throw Exception('Analyze failed');
    if (_representation != null) return _representation!;
    return ScreenRepresentation(
      elements: [],
      textItems: [],
      regions: [],
      timestamp: DateTime.now(),
      overallConfidence: 0.8,
    );
  }
}

/// Fake ScreenSearchService.
class FakeScreenSearchService implements ScreenSearchService {
  bool shouldThrow = false;
  List<DetectedTarget>? _targets;

  void setTargets(List<DetectedTarget> targets) => _targets = targets;

  @override
  Future<List<DetectedTarget>> search(TargetQuery query) async {
    if (shouldThrow) throw Exception('Search failed');
    if (_targets != null) return _targets!;
    return [];
  }
}

void main() {
  late ActionVerifier verifier;
  late FakeScreenCaptureService capture;
  late FakeScreenUnderstandingEngine understanding;
  late FakeScreenSearchService search;

  setUp(() {
    capture = FakeScreenCaptureService();
    understanding = FakeScreenUnderstandingEngine();
    search = FakeScreenSearchService();
    verifier = ActionVerifier(
      screenCapture: capture,
      screenUnderstanding: understanding,
      screenSearch: search,
    );
  });

  // ─── VerificationMethod.none ──────────────────────────────────────
  group('ActionVerifier verify none', () {
    test('none method skips verification and passes', () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.none,
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull!.passed, isTrue);
    });

    test('none method returns high confidence', () async {
      final action = DeviceAction.back();
      final params = VerificationParams(
        method: VerificationMethod.none,
      );
      final result = await verifier.verify(action, params);
      expect(result.valueOrNull!.confidence, greaterThanOrEqualTo(0.5));
    });
  });

  // ─── VerificationMethod.pixelChange ───────────────────────────────
  group('ActionVerifier verify pixelChange', () {
    test('pixelChange method with successful capture returns result',
        () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'button',
      );
      final params = VerificationParams(
        method: VerificationMethod.pixelChange,
        originalTarget: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await verifier.verify(action, params);
      // Should return a result (pass or fail depends on implementation)
      expect(result.isFailure, isFalse);
    });

    test('pixelChange method capture failure returns verification failure',
        () async {
      capture.shouldThrow = true;
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.pixelChange,
        originalTarget: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.verification);
    });
  });

  // ─── VerificationMethod.targetDisappear ───────────────────────────
  group('ActionVerifier verify targetDisappear', () {
    test('targetDisappear without originalTarget uses action.targetLabel',
        () async {
      search.setTargets([]); // target not found after action = disappeared
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'dialog',
      );
      final params = VerificationParams(
        method: VerificationMethod.targetDisappear,
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull!.passed, isTrue);
    });

    test('targetDisappear with originalTarget succeeds when target gone',
        () async {
      search.setTargets([]); // target disappeared
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.targetDisappear,
        originalTarget: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull!.passed, isTrue);
    });

    test('targetDisappear fails when target is still present', () async {
      search.setTargets([
        DetectedTarget(
          label: 'dialog',
          bounds: Rect.fromLTWH(200, 400, 300, 100),
          confidence: 0.9,
          category: 'dialog',
          metadata: {},
        ),
      ]);
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.3, y: 0.25),
        targetLabel: 'dialog',
      );
      final params = VerificationParams(
        method: VerificationMethod.targetDisappear,
        originalTarget: const NormalizedPoint(x: 0.3, y: 0.25),
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isFalse); // returns VerificationResult
      expect(result.valueOrNull!.passed, isFalse);
    });

    test(
        'targetDisappear without originalTarget or targetLabel returns failure',
        () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        // No targetLabel set
      );
      final params = VerificationParams(
        method: VerificationMethod.targetDisappear,
        // No originalTarget
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.verification);
    });
  });

  // ─── VerificationMethod.targetAppear ──────────────────────────────
  group('ActionVerifier verify targetAppear', () {
    test('targetAppear with expectedTarget succeeds when target found',
        () async {
      search.setTargets([
        DetectedTarget(
          label: 'new screen',
          bounds: Rect.fromLTWH(100, 100, 400, 300),
          confidence: 0.88,
          category: 'screen',
          metadata: {},
        ),
      ]);
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.targetAppear,
        expectedTarget: const NormalizedPoint(x: 0.2, y: 0.15),
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull!.passed, isTrue);
    });

    test(
        'targetAppear without expectedTarget returns verification failure',
        () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.targetAppear,
        // No expectedTarget
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.verification);
    });
  });

  // ─── VerificationMethod.textMatch ─────────────────────────────────
  group('ActionVerifier verify textMatch', () {
    test(
        'textMatch with expectedText succeeds when text is found on screen',
        () async {
      understanding.setRepresentation(ScreenRepresentation(
        elements: [],
        textItems: [
          ScreenTextItem(
            text: 'Success',
            bounds: Rect.fromLTWH(200, 300, 200, 50),
            confidence: 0.95,
          ),
        ],
        regions: [],
        timestamp: DateTime.now(),
        overallConfidence: 0.9,
      ));
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.textMatch,
        expectedText: 'Success',
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull!.passed, isTrue);
    });

    test('textMatch without expectedText returns verification failure',
        () async {
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.textMatch,
        // No expectedText
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.verification);
    });
  });

  // ─── Capture/analyze failure across methods ───────────────────────
  group('ActionVerifier capture/analyze failure', () {
    test('analyze failure returns verification failure', () async {
      understanding.shouldThrow = true;
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.pixelChange,
        originalTarget: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isTrue);
    });

    test('search failure for targetDisappear returns verification failure',
        () async {
      search.shouldThrow = true;
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'target',
      );
      final params = VerificationParams(
        method: VerificationMethod.targetDisappear,
      );
      final result = await verifier.verify(action, params);
      expect(result.isFailure, isTrue);
    });
  });
}
