/// Stub implementation of [AssistantService] for testing.
///
/// In production, the [AssistantMethodChannel] implementation is used.
/// This stub allows unit testing and structural verification without
/// a real Android platform.
library;

import 'package:aura_assistant/core/errors/result.dart';
import '../domain/entities/assistant_status.dart';
import '../domain/entities/assistant_invocation.dart';
import '../domain/models/assistant_failure.dart';
import '../domain/assistant_service.dart';

/// Configurable stub for testing the assistant integration feature.
class StubAssistantService implements AssistantService {
  /// The status to return from [detectStatus].
  AssistantStatus detectStatusResult;

  /// Whether [openAssistantSettings] should succeed.
  bool openSettingsSucceeds;

  /// The invocation data to return from [getInvocationData].
  AssistantInvocation? invocationDataResult;

  /// Whether the assistant role is reported as supported.
  bool isSupportedResult;

  /// If non-null, [detectStatus] returns this failure instead of a status.
  AssistantFailure? detectStatusFailure;

  /// If non-null, [openAssistantSettings] returns this failure.
  AssistantFailure? openSettingsFailure;

  /// If non-null, [getInvocationData] returns this failure.
  AssistantFailure? getInvocationFailure;

  int _detectCallCount = 0;
  int _openSettingsCallCount = 0;
  int _getInvocationCallCount = 0;
  int _isSupportedCallCount = 0;

  StubAssistantService({
    this.detectStatusResult = const AssistantStatus(
      availability: AssistantAvailability.available,
    ),
    this.openSettingsSucceeds = true,
    this.invocationDataResult,
    this.isSupportedResult = true,
    this.detectStatusFailure,
    this.openSettingsFailure,
    this.getInvocationFailure,
  });

  int get detectCallCount => _detectCallCount;
  int get openSettingsCallCount => _openSettingsCallCount;
  int get getInvocationCallCount => _getInvocationCallCount;
  int get isSupportedCallCount => _isSupportedCallCount;

  @override
  Future<Result<AssistantStatus, AssistantFailure>> detectStatus() async {
    _detectCallCount++;
    if (detectStatusFailure != null) {
      return Result.failure(detectStatusFailure!);
    }
    return Result.success(detectStatusResult);
  }

  @override
  Future<Result<void, AssistantFailure>> openAssistantSettings() async {
    _openSettingsCallCount++;
    if (openSettingsFailure != null) {
      return Result.failure(openSettingsFailure!);
    }
    return Result.success(null);
  }

  @override
  Future<Result<AssistantInvocation, AssistantFailure>>
      getInvocationData() async {
    _getInvocationCallCount++;
    if (getInvocationFailure != null) {
      return Result.failure(getInvocationFailure!);
    }
    if (invocationDataResult != null) {
      return Result.success(invocationDataResult!);
    }
    return AssistantFailure.invocationParseFailed(
      StateError('No invocation data configured in stub.'),
    ).asFailure();
  }

  @override
  Future<Result<bool, AssistantFailure>> isAssistantRoleSupported() async {
    _isSupportedCallCount++;
    if (detectStatusFailure != null) {
      return Result.failure(detectStatusFailure!);
    }
    return Result.success(isSupportedResult);
  }
}
