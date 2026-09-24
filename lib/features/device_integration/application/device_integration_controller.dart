import '../domain/entities/device_action.dart';
import '../domain/models/device_integration_failure.dart';
import '../domain/models/device_integration_state.dart';
import '../domain/models/permission_status.dart';
import 'action_validator.dart';
import 'action_verifier.dart';
import 'target_resolver.dart';
import '../infrastructure/android_device_executor.dart';
import '../../../core/errors/result.dart';

/// Coordinates device actions through validation, execution and verification.
///
/// This class intentionally contains orchestration only. Native device
/// operations remain inside [AndroidDeviceExecutor] and the underlying
/// platform channels.
class DeviceIntegrationController {
  DeviceIntegrationController({
    required this.validator,
    required this.targetResolver,
    required this.executor,
    required this.verifier,
    required this.permissionManager,
  });

  final ActionValidator validator;
  final TargetResolver targetResolver;
  final AndroidDeviceExecutor executor;
  final ActionVerifier verifier;
  final PermissionManager permissionManager;

  DeviceIntegrationState _state = const DeviceIntegrationState();
  final List<void Function(DeviceIntegrationState)> _listeners = [];

  bool _active = false;
  bool _processing = false;

  DeviceIntegrationState get state => _state;
  bool get isActive => _active;

  void activate() {
    if (_active) return;
    _active = true;
    _emit(_state.copyWith(isActive: true));
  }

  void deactivate() {
    if (!_active) return;
    _active = false;
    _emit(_state.copyWith(isActive: false));
  }

  void addStateListener(void Function(DeviceIntegrationState) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeStateListener(void Function(DeviceIntegrationState) listener) {
    _listeners.remove(listener);
  }

  Future<Result<void, DeviceIntegrationFailure>> processAction(
    DeviceAction action, {
    VerificationParams? verification,
    int? frameWidth,
    int? frameHeight,
  }) async {
    if (!_active) {
      final failure = DeviceIntegrationFailure.cancellation(
        'Device integration is inactive.',
        action: action,
      );
      _fail(failure);
      return Result.failure(failure);
    }

    if (_processing) {
      final failure = DeviceIntegrationFailure.cancellation(
        'Another device action is already being processed.',
        action: action,
      );
      _fail(failure);
      return Result.failure(failure);
    }

    _processing = true;
    _emit(_state.copyWith(
      processingState: DeviceIntegrationProcessingState.validating,
      currentAction: action,
      clearError: true,
      clearWarning: true,
    ));

    try {
      final validation = await validator.validate(action);

      if (validation.isFailure) {
        final failure = validation.failureOrNull!;
        _fail(failure);
        return Result.failure(failure);
      }

      _emit(_state.copyWith(
        processingState: DeviceIntegrationProcessingState.executing,
        currentAction: action,
      ));

      final execution = await executor.execute(
        action,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      );

      if (execution.isFailure) {
        final failure = execution.failureOrNull!;
        _fail(failure);
        return Result.failure(failure);
      }

      if (verification != null) {
        _emit(_state.copyWith(
          processingState: DeviceIntegrationProcessingState.verifying,
          currentAction: action,
        ));

        final verified = await verifier.verify(action, verification);

        if (verified.isFailure) {
          final failure = verified.failureOrNull!;
          _fail(failure);
          return Result.failure(failure);
        }

        final result = verified.valueOrNull;
        if (result == null || !result.passed) {
          final failure = DeviceIntegrationFailure.verification(
            'Device action verification failed.',
            action: action,
          );
          _fail(failure);
          return Result.failure(failure);
        }
      }

      _succeed(action);
      return const Result.success(null);
    } catch (e) {
      final failure = DeviceIntegrationFailure.execution(
        'Unexpected device integration error: $e',
        action: action,
      );
      _fail(failure);
      return Result.failure(failure);
    } finally {
      _processing = false;
    }
  }

  void enqueueAction(DeviceAction action) {
    final queue = List<DeviceAction>.from(_state.actionQueue)
      ..add(action);

    _emit(_state.copyWith(actionQueue: queue));
  }

  Future<Result<void, DeviceIntegrationFailure>?> processNextInQueue({
    VerificationParams? verification,
    int? frameWidth,
    int? frameHeight,
  }) async {
    if (_state.actionQueue.isEmpty) {
      return null;
    }

    final action = _state.actionQueue.first;
    final queue = List<DeviceAction>.from(_state.actionQueue)
      ..removeAt(0);

    _emit(_state.copyWith(actionQueue: queue));

    return processAction(
      action,
      verification: verification,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
  }

  Future<void> cancel() async {
    await executor.cancel();

    _processing = false;
    _emit(_state.copyWith(
      processingState: DeviceIntegrationProcessingState.idle,
      clearCurrentAction: true,
      warning: 'Device action cancelled.',
    ));
  }

  Future<PermissionResult> requestPermissions() async {
    _emit(_state.copyWith(
      processingState: DeviceIntegrationProcessingState.awaitingPermission,
    ));

    try {
      final result = await permissionManager.requestAll();

      _emit(_state.copyWith(
        processingState: DeviceIntegrationProcessingState.idle,
        warning: result.allGranted
            ? null
            : 'Some device permissions are not granted.',
      ));

      return result;
    } catch (e) {
      _emit(_state.copyWith(
        processingState: DeviceIntegrationProcessingState.failure,
        warning: 'Permission request failed: $e',
      ));
      rethrow;
    }
  }

  /// Converts an agent-style action map into a [DeviceAction].
  ///
  /// Supported action names:
  /// tap, long_press, swipe, text_input, open_app, back, home.
  Result<DeviceAction, DeviceIntegrationFailure> parseActionFromMap(
    Map<String, dynamic> data,
  ) {
    try {
      final rawType = (data['type'] ?? data['action'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      switch (rawType) {
        case 'tap':
          return Result.success(
            DeviceAction.tap(
              targetPoint: NormalizedPoint(
                x: _number(data['x']),
                y: _number(data['y']),
              ),
              targetLabel: data['target_label']?.toString(),
            ),
          );

        case 'long_press':
        case 'longpress':
          return Result.success(
            DeviceAction.longPress(
              targetPoint: NormalizedPoint(
                x: _number(data['x']),
                y: _number(data['y']),
              ),
              durationMs: _int(data['duration_ms']) ?? 600,
              targetLabel: data['target_label']?.toString(),
            ),
          );

        case 'swipe':
          return Result.success(
            DeviceAction.swipe(
              swipeStart: NormalizedPoint(
                x: _number(data['start_x']),
                y: _number(data['start_y']),
              ),
              swipeEnd: NormalizedPoint(
                x: _number(data['end_x']),
                y: _number(data['end_y']),
              ),
              durationMs: _int(data['duration_ms']) ?? 350,
            ),
          );

        case 'text_input':
        case 'textinput':
          return Result.success(
            DeviceAction.textInput(
              text: data['text']?.toString() ?? '',
              targetPoint: data['x'] != null && data['y'] != null
                  ? NormalizedPoint(
                      x: _number(data['x']),
                      y: _number(data['y']),
                    )
                  : null,
            ),
          );

        case 'open_app':
        case 'openapp':
          return Result.success(
            DeviceAction.openApp(
              packageName: data['package_name']?.toString() ?? '',
            ),
          );

        case 'back':
          return Result.success(DeviceAction.back());

        case 'home':
          return Result.success(DeviceAction.home());

        default:
          return Result.failure(
            DeviceIntegrationFailure.validation(
              'Unknown device action type: $rawType',
            ),
          );
      }
    } catch (e) {
      return Result.failure(
        DeviceIntegrationFailure.validation(
          'Invalid device action data: $e',
        ),
      );
    }
  }

  Future<Result<DeviceAction, DeviceIntegrationFailure>>
      processAgentResponse(Map<String, dynamic> data) async {
    final parsed = parseActionFromMap(data);

    if (parsed.isFailure) {
      return Result.failure(parsed.failureOrNull!);
    }

    final action = parsed.valueOrNull;
    if (action == null) {
      return const Result.failure(
        DeviceIntegrationFailure.validation(
          'Agent response did not contain a valid device action.',
        ),
      );
    }

    return Result.success(action);
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();

    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Invalid numeric value: $value');
    }

    return parsed;
  }

  int? _int(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  void _succeed(DeviceAction action) {
    _emit(_state.copyWith(
      processingState: DeviceIntegrationProcessingState.success,
      currentAction: action,
      lastCompletedAction: action,
      clearError: true,
      clearWarning: true,
    ));

    _emit(_state.copyWith(
      processingState: DeviceIntegrationProcessingState.idle,
      clearCurrentAction: true,
      successCount: _state.successCount + 1,
    ));
  }

  void _fail(DeviceIntegrationFailure failure) {
    _emit(_state.copyWith(
      processingState: DeviceIntegrationProcessingState.failure,
      lastError: failure,
      failureCount: _state.failureCount + 1,
      securityRejectionCount:
          failure.phase == DeviceIntegrationFailurePhase.security
              ? _state.securityRejectionCount + 1
              : _state.securityRejectionCount,
    ));

    _emit(_state.copyWith(
      processingState: DeviceIntegrationProcessingState.idle,
      clearCurrentAction: true,
    ));
  }

  void _emit(DeviceIntegrationState next) {
    _state = next;

    for (final listener in List<void Function(DeviceIntegrationState)>.from(
      _listeners,
    )) {
      try {
        listener(_state);
      } catch (_) {
        // A listener must never break device-action orchestration.
      }
    }
  }
}
