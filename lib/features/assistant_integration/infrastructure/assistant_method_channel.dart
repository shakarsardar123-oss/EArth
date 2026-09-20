/// MethodChannel bridge for Android default-assistant operations.
///
/// Follows the project convention: channel name matches
/// `com.aura.assistant/<feature_name>`.
///
/// Methods exposed to the Flutter side:
/// - `checkIsDefaultAssistant` → bool
/// - `getAssistantAvailability` → String ('unsupported'|'available'|'active')
/// - `openAssistantSettings` → void
/// - `getInvocationData` → Map (assistContext, assistUri, callingPackage, trigger)
/// - `getAndroidApiLevel` → int
library;

import 'package:flutter/services.dart';
import 'package:aura_assistant/core/errors/result.dart';
import '../domain/entities/assistant_status.dart';
import '../domain/entities/assistant_invocation.dart';
import '../domain/models/assistant_failure.dart';
import '../domain/assistant_service.dart';

/// MethodChannel name following project convention.
const String _kChannelName = 'com.aura.assistant/assistant_integration';

/// Method names invoked on the platform side.
abstract class AssistantMethodNames {
  static const String checkIsDefaultAssistant = 'checkIsDefaultAssistant';
  static const String getAssistantAvailability = 'getAssistantAvailability';
  static const String openAssistantSettings = 'openAssistantSettings';
  static const String getInvocationData = 'getInvocationData';
  static const String getAndroidApiLevel = 'getAndroidApiLevel';
}

/// MethodChannel-based implementation of [AssistantService].
class AssistantMethodChannel implements AssistantService {
  final MethodChannel _channel;

  AssistantMethodChannel({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel(_kChannelName);

  @override
  Future<Result<AssistantStatus, AssistantFailure>> detectStatus() async {
    try {
      final availabilityStr = await _channel.invokeMethod<String>(
            AssistantMethodNames.getAssistantAvailability,
          ) ??
          'unsupported';

      final apiLevel = await _channel.invokeMethod<int>(
        AssistantMethodNames.getAndroidApiLevel,
      );

      final isDefault = availabilityStr == 'active';

      String? currentDefaultPackage;
      if (!isDefault && availabilityStr == 'available') {
        // On the platform side, we could also query the current default
        // package name. For now, leave it null unless AURA is active.
        currentDefaultPackage = null;
      }

      final availability = AssistantAvailability.values.firstWhere(
        (e) => e.name == availabilityStr,
        orElse: () => AssistantAvailability.unsupported,
      );

      return Result.success(AssistantStatus(
        availability: availability,
        currentDefaultPackage: currentDefaultPackage,
        androidApiLevel: apiLevel,
        lastChecked: DateTime.now(),
      ));
    } on PlatformException catch (e) {
      return AssistantFailure.statusCheckFailed(e).asFailure();
    } catch (e) {
      return AssistantFailure.statusCheckFailed(e).asFailure();
    }
  }

  @override
  Future<Result<void, AssistantFailure>> openAssistantSettings() async {
    try {
      await _channel.invokeMethod<void>(
        AssistantMethodNames.openAssistantSettings,
      );
      return Result.success(null);
    } on PlatformException catch (e) {
      return AssistantFailure.openSettingsFailed(e).asFailure();
    } catch (e) {
      return AssistantFailure.openSettingsFailed(e).asFailure();
    }
  }

  @override
  Future<Result<AssistantInvocation, AssistantFailure>>
      getInvocationData() async {
    try {
      final data = await _channel.invokeMethod<Map>(
        AssistantMethodNames.getInvocationData,
      );

      if (data == null) {
        return AssistantFailure.invocationParseFailed(
          StateError('No invocation data received from platform.'),
        ).asFailure();
      }

      final triggerStr = data['trigger'] as String? ?? 'unknown';
      final trigger = InvocationTrigger.values.firstWhere(
        (e) => e.name == triggerStr,
        orElse: () => InvocationTrigger.unknown,
      );

      final invocation = AssistantInvocation(
        trigger: trigger,
        assistContext: data['assistContext'] as String?,
        assistUri: data['assistUri'] as String?,
        callingPackage: data['callingPackage'] as String?,
        invokedAt: DateTime.now(),
        statusAtInvocation: const AssistantStatus(),
      );

      return Result.success(invocation);
    } on PlatformException catch (e) {
      return AssistantFailure.invocationParseFailed(e).asFailure();
    } catch (e) {
      return AssistantFailure.invocationParseFailed(e).asFailure();
    }
  }

  @override
  Future<Result<bool, AssistantFailure>> isAssistantRoleSupported() async {
    try {
      final availabilityStr = await _channel.invokeMethod<String>(
            AssistantMethodNames.getAssistantAvailability,
          ) ??
          'unsupported';

      return Result.success(availabilityStr != 'unsupported');
    } on PlatformException catch (e) {
      return AssistantFailure.statusCheckFailed(e).asFailure();
    } catch (e) {
      return AssistantFailure.statusCheckFailed(e).asFailure();
    }
  }
}
