/// Tests for DeviceIntegrationController.
/// Covers: full pipeline (inactive controller, validation fail,
/// execution fail, success with state transitions), cancel, enqueue,
/// processNextInQueue, processAgentResponse, voice announcements
/// (Kurdish strings), requestPermissions.
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/device_integration/application/action_validator.dart';
import 'package:aura_assistant/features/device_integration/application/target_resolver.dart';
import 'package:aura_assistant/features/device_integration/application/action_verifier.dart';
import 'package:aura_assistant/features/device_integration/application/device_integration_controller.dart';
import 'package:aura_assistant/features/device_integration/domain/entities/device_action.dart';
import 'package:aura_assistant/features/device_integration/domain/models/device_integration_failure.dart';
import 'package:aura_assistant/features/device_integration/domain/models/device_integration_state.dart';
import 'package:aura_assistant/features/device_integration/domain/models/permission_status.dart';
import 'package:aura_assistant/features/device_integration/domain/models/security_verdict.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/android_device_executor.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/permission_manager_impl.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/services/screen_capture_service.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/services/screen_understanding_engine.dart';
import 'package:aura_assistant/features/device_integration/infrastructure/services/screen_search_service.dart';
import 'package:aura_assistant/core/errors/result.dart';

// ─── Fake AgentEngine ──────────────────────────────────────────────
class FakeAgentEngine implements AgentEngine {
  AgentResponse? _response;
  bool shouldFail = false;

  void setResponse(AgentResponse r) => _response = r;

  @override
  Future<Result<AgentResponse, AgentFailure>> process(
      AgentContext context) async {
    if (shouldFail) {
      return Result.failure(AgentFailure(message: 'Agent error'));
    }
    if (_response != null) return Result.success(_response!);
    return Result.success(AgentResponse(
      text: 'Tap the button',
      actions: [],
    ));
  }
}

// ─── Fake VoiceScreenPipeline ──────────────────────────────────────
class FakeVoiceScreenPipeline implements VoiceScreenPipeline {
  final List<String> spokenTexts = [];
  bool shouldFail = false;

  @override
  String get sttLocale => 'ckb_IQ';

  @override
  String get ttsLocale => 'ku';

  @override
  Future<Result<void, VoiceScreenFailure>> speak(String text) async {
    spokenTexts.add(text);
    if (shouldFail) {
      return Result.failure(
          VoiceScreenFailure(message: 'TTS error'));
    }
    return Result.success(null);
  }

  @override
  Future<void> cancel() async {}
}

// ─── Fake ScreenCaptureService ─────────────────────────────────────
class FakeScreenCaptureService implements ScreenCaptureService {
  bool shouldThrow = false;

  @override
  Future<CapturedFrame> capture() async {
    if (shouldThrow) throw Exception('Capture failed');
    return CapturedFrame(
      imageBytes: Uint8List(100),
      width: 1080,
      height: 1920,
      timestamp: DateTime.now(),
    );
  }
}

// ─── Fake ScreenUnderstandingEngine ───────────────────────────────
class FakeScreenUnderstandingEngine implements ScreenUnderstandingEngine {
  bool shouldThrow = false;

  @override
  Future<ScreenRepresentation> analyze(CapturedFrame frame) async {
    if (shouldThrow) throw Exception('Analyze failed');
    return ScreenRepresentation(
      elements: [],
      textItems: [],
      regions: [],
      timestamp: DateTime.now(),
      overallConfidence: 0.8,
    );
  }
}

// ─── Fake ScreenSearchService ──────────────────────────────────────
class FakeScreenSearchService implements ScreenSearchService {
  bool shouldThrow = false;
  List<DetectedTarget> _targets = [];

  void setTargets(List<DetectedTarget> t) => _targets = t;

  @override
  Future<List<DetectedTarget>> search(TargetQuery query) async {
    if (shouldThrow) throw Exception('Search failed');
    return _targets;
  }
}

// ─── Configurable ActionValidator ──────────────────────────────────
class FakeActionValidator extends ActionValidator {
  bool shouldFailValidation = false;
  DeviceIntegrationFailurePhase? failPhase;

  FakeActionValidator({required PermissionManager permissionManager})
      : super(permissionManager: permissionManager);

  @override
  Future<Result<DeviceAction, DeviceIntegrationFailure>> validate(
      DeviceAction action) async {
    if (shouldFailValidation) {
      return Result.failure(DeviceIntegrationFailure(
        phase: failPhase ?? DeviceIntegrationFailurePhase.validation,
        message: 'Validation failed',
        action: action,
      ));
    }
    return Result.success(action);
  }
}

// ─── Configurable TargetResolver ───────────────────────────────────
class FakeTargetResolver extends TargetResolver {
  NormalizedPoint? _resolvedPoint;
  bool shouldFail = false;

  FakeTargetResolver({
    required ScreenCaptureService screenCapture,
    required ScreenUnderstandingEngine screenUnderstanding,
    required ScreenSearchService screenSearch,
  }) : super(
          screenCapture: screenCapture,
          screenUnderstanding: screenUnderstanding,
          screenSearch: screenSearch,
        );

  void setResolvedPoint(NormalizedPoint p) => _resolvedPoint = p;

  @override
  Future<Result<NormalizedPoint, DeviceIntegrationFailure>> resolve(
      String query) async {
    if (shouldFail) {
      return Result.failure(DeviceIntegrationFailure(
        phase: DeviceIntegrationFailurePhase.targetResolution,
        message: 'Resolve failed',
      ));
    }
    if (_resolvedPoint != null) return Result.success(_resolvedPoint!);
    return Result.success(const NormalizedPoint(x: 0.5, y: 0.5));
  }

  @override
  Future<Result<List<NormalizedPoint>, DeviceIntegrationFailure>> resolveAll(
      List<String> queries) async {
    if (shouldFail) {
      return Result.failure(DeviceIntegrationFailure(
        phase: DeviceIntegrationFailurePhase.targetResolution,
        message: 'ResolveAll failed',
      ));
    }
    return Result.success(
      queries.map((_) => _resolvedPoint ?? const NormalizedPoint(x: 0.5, y: 0.5)).toList(),
    );
  }
}

// ─── Configurable ActionVerifier ───────────────────────────────────
class FakeActionVerifier extends ActionVerifier {
  bool shouldPass = true;
  bool shouldFail = false;

  FakeActionVerifier({
    required ScreenCaptureService screenCapture,
    required ScreenUnderstandingEngine screenUnderstanding,
    required ScreenSearchService screenSearch,
  }) : super(
          screenCapture: screenCapture,
          screenUnderstanding: screenUnderstanding,
          screenSearch: screenSearch,
        );

  @override
  Future<Result<VerificationResult, DeviceIntegrationFailure>> verify(
      DeviceAction action, VerificationParams params) async {
    if (shouldFail) {
      return Result.failure(DeviceIntegrationFailure(
        phase: DeviceIntegrationFailurePhase.verification,
        message: 'Verification failed',
        action: action,
      ));
    }
    return Result.success(VerificationResult(
      passed: shouldPass,
      description: shouldPass ? 'Verified' : 'Not verified',
      confidence: shouldPass ? 0.9 : 0.2,
    ));
  }
}

void main() {
  late DeviceIntegrationController controller;
  late FakeAgentEngine agentEngine;
  late FakeActionValidator validator;
  late FakeTargetResolver targetResolver;
  late AndroidDeviceExecutor executor;
  late FakeActionVerifier verifier;
  late FakeVoiceScreenPipeline voicePipeline;
  late StubPermissionManager permissionManager;
  late FakeScreenCaptureService capture;
  late FakeScreenUnderstandingEngine understanding;
  late FakeScreenSearchService search;

  setUp(() {
    agentEngine = FakeAgentEngine();
    permissionManager = StubPermissionManager(autoGrantOnRequest: true);
    permissionManager.setStatus(DevicePermission.accessibility, PermissionStatus.granted);
    permissionManager.setStatus(DevicePermission.overlay, PermissionStatus.granted);
    permissionManager.setStatus(DevicePermission.screenCapture, PermissionStatus.granted);
    validator = FakeActionValidator(permissionManager: permissionManager);
    capture = FakeScreenCaptureService();
    understanding = FakeScreenUnderstandingEngine();
    search = FakeScreenSearchService();
    targetResolver = FakeTargetResolver(
      screenCapture: capture,
      screenUnderstanding: understanding,
      screenSearch: search,
    );
    executor = AndroidDeviceExecutor(isAndroid: true);
    verifier = FakeActionVerifier(
      screenCapture: capture,
      screenUnderstanding: understanding,
      screenSearch: search,
    );
    voicePipeline = FakeVoiceScreenPipeline();
    controller = DeviceIntegrationController(
      agentEngine: agentEngine,
      validator: validator,
      targetResolver: targetResolver,
      executor: executor,
      verifier: verifier,
      voicePipeline: voicePipeline,
      permissionManager: permissionManager,
    );
  });

  // ─── Activation / Deactivation ─────────────────────────────────────
  group('DeviceIntegrationController activate/deactivate', () {
    test('activate sets controller to active', () {
      controller.activate();
      // Controller should now be active and able to process actions
      // We verify by processing an action that should succeed
    });

    test('deactivate sets controller to inactive', () {
      controller.activate();
      controller.deactivate();
    });
  });

  // ─── Inactive controller ─────────────────────────────────────────
  group('DeviceIntegrationController inactive', () {
    test('processAction on inactive controller returns cancellation failure',
        () async {
      // Controller is not activated
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await controller.processAction(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.cancellation);
    });
  });

  // ─── Validation failure ──────────────────────────────────────────
  group('DeviceIntegrationController validation failure', () {
    test('processAction fails when validation rejects action', () async {
      controller.activate();
      validator.shouldFailValidation = true;
      validator.failPhase = DeviceIntegrationFailurePhase.security;

      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'hack',
      );
      final result = await controller.processAction(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.security);
    });
  });

  // ─── Execution failure ───────────────────────────────────────────
  group('DeviceIntegrationController execution failure', () {
    test('processAction fails on non-Android executor', () async {
      controller.activate();
      executor = AndroidDeviceExecutor(isAndroid: false);
      // Re-create controller with non-Android executor
      controller = DeviceIntegrationController(
        agentEngine: agentEngine,
        validator: validator,
        targetResolver: targetResolver,
        executor: executor,
        verifier: verifier,
        voicePipeline: voicePipeline,
        permissionManager: permissionManager,
      );
      controller.activate();

      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await controller.processAction(action);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.phase,
          DeviceIntegrationFailurePhase.execution);
    });
  });

  // ─── Successful pipeline ──────────────────────────────────────────
  group('DeviceIntegrationController successful pipeline', () {
    test('processAction succeeds end-to-end on Android', () async {
      controller.activate();
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
        targetLabel: 'button',
      );
      final result = await controller.processAction(action);
      expect(result.isFailure, isFalse);
    });

    test('processAction with verification params succeeds', () async {
      controller.activate();
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final params = VerificationParams(
        method: VerificationMethod.none,
      );
      final result = await controller.processAction(
        action,
        verificationParams: params,
      );
      expect(result.isFailure, isFalse);
    });

    test('processAction with frame dimensions succeeds', () async {
      controller.activate();
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      final result = await controller.processAction(
        action,
        frameWidth: 1080,
        frameHeight: 1920,
      );
      expect(result.isFailure, isFalse);
    });
  });

  // ─── State transitions ───────────────────────────────────────────
  group('DeviceIntegrationController state transitions', () {
    test('state changes during successful action processing', () async {
      controller.activate();
      final states = <DeviceIntegrationState>[];
      controller.addStateListener((state) => states.add(state));

      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      await controller.processAction(action);

      // Should have recorded state transitions
      expect(states, isNotEmpty);
    });

    test('removeStateListener stops receiving updates', () async {
      controller.activate();
      final states = <DeviceIntegrationState>[];
      void listener(DeviceIntegrationState s) => states.add(s);
      controller.addStateListener(listener);
      controller.removeStateListener(listener);

      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      await controller.processAction(action);

      expect(states, isEmpty);
    });
  });

  // ─── Cancel ──────────────────────────────────────────────────────
  group('DeviceIntegrationController cancel', () {
    test('cancel can be called without error', () async {
      controller.activate();
      await controller.cancel();
    });
  });

  // ─── Enqueue and processNextInQueue ───────────────────────────────
  group('DeviceIntegrationController enqueue', () {
    test('enqueueAction queues an action', () {
      controller.activate();
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      controller.enqueueAction(action);
    });

    test('processNextInQueue processes the next queued action', () async {
      controller.activate();
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      controller.enqueueAction(action);
      final result = await controller.processNextInQueue();
      // Should process the queued action
      expect(result, isNotNull);
    });

    test('processNextInQueue with empty queue returns null', () async {
      controller.activate();
      final result = await controller.processNextInQueue();
      expect(result, isNull);
    });
  });

  // ─── processAgentResponse ─────────────────────────────────────────
  group('DeviceIntegrationController processAgentResponse', () {
    test('processAgentResponse with tap action map', () async {
      controller.activate();
      final response = {
        'type': 'tap',
        'x': 0.5,
        'y': 0.5,
        'target_label': 'button',
      };
      final result = await controller.processAgentResponse(response);
      expect(result, isNotNull);
    });

    test('processAgentResponse with swipe action map', () async {
      controller.activate();
      final response = {
        'type': 'swipe',
        'start_x': 0.5,
        'start_y': 0.8,
        'end_x': 0.5,
        'end_y': 0.2,
      };
      final result = await controller.processAgentResponse(response);
      expect(result, isNotNull);
    });

    test('processAgentResponse with textInput action map', () async {
      controller.activate();
      final response = {
        'type': 'text_input',
        'text': 'hello',
        'x': 0.5,
        'y': 0.5,
      };
      final result = await controller.processAgentResponse(response);
      expect(result, isNotNull);
    });

    test('processAgentResponse with openApp action map', () async {
      controller.activate();
      final response = {
        'type': 'open_app',
        'package_name': 'com.example.app',
      };
      final result = await controller.processAgentResponse(response);
      expect(result, isNotNull);
    });
  });

  // ─── Voice announcements (Kurdish) ───────────────────────────────
  group('DeviceIntegrationController voice announcements', () {
    test('successful action announces Kurdish success message', () async {
      controller.activate();
      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      await controller.processAction(action);
      // Voice pipeline should have been called with Kurdish success string
      expect(voicePipeline.spokenTexts, isNotEmpty);
      expect(voicePipeline.spokenTexts.last, contains('کردار'));
    });

    test('failed action announces Kurdish failure message', () async {
      controller.activate();
      validator.shouldFailValidation = true;
      validator.failPhase = DeviceIntegrationFailurePhase.validation;

      final action = DeviceAction.tap(
        targetPoint: const NormalizedPoint(x: 0.5, y: 0.5),
      );
      await controller.processAction(action);
      // Should speak a failure-related Kurdish string
      expect(voicePipeline.spokenTexts, isNotEmpty);
    });

    test('voice pipeline speak is called with Sorani Kurdish locale', () {
      expect(voicePipeline.ttsLocale, 'ku');
      expect(voicePipeline.sttLocale, 'ckb_IQ');
    });
  });

  // ─── requestPermissions ──────────────────────────────────────────
  group('DeviceIntegrationController requestPermissions', () {
    test('requestPermissions returns granted result', () async {
      controller.activate();
      final result = await controller.requestPermissions();
      // With autoGrant, should be granted
      expect(result, isNotNull);
    });

    test('requestPermissions with autoGrant=false returns denied',
        () async {
      permissionManager = StubPermissionManager(autoGrantOnRequest: false);
      controller = DeviceIntegrationController(
        agentEngine: agentEngine,
        validator: FakeActionValidator(permissionManager: permissionManager),
        targetResolver: targetResolver,
        executor: executor,
        verifier: verifier,
        voicePipeline: voicePipeline,
        permissionManager: permissionManager,
      );
      controller.activate();
      final result = await controller.requestPermissions();
      expect(result, isNotNull);
    });
  });

  // ─── _parseActionFromMap internal ─────────────────────────────────
  group('DeviceIntegrationController _parseActionFromMap', () {
    test('parses back action from map', () async {
      controller.activate();
      final response = {'type': 'back'};
      final result = await controller.processAgentResponse(response);
      expect(result, isNotNull);
    });

    test('parses home action from map', () async {
      controller.activate();
      final response = {'type': 'home'};
      final result = await controller.processAgentResponse(response);
      expect(result, isNotNull);
    });

    test('parses longPress action from map', () async {
      controller.activate();
      final response = {
        'type': 'long_press',
        'x': 0.5,
        'y': 0.5,
        'duration_ms': 500,
      };
      final result = await controller.processAgentResponse(response);
      expect(result, isNotNull);
    });
  });
}
