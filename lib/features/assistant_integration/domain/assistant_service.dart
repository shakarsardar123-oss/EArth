/// Abstract service for Android assistant role operations.
///
/// Defines the contract for:
/// 1. Detecting whether the platform supports the assistant role.
/// 2. Checking whether AURA is the current default assistant.
/// 3. Opening the system assistant-settings activity.
/// 4. Receiving invocation data from the platform.
///
/// The concrete implementation lives in the infrastructure layer
/// and delegates to a MethodChannel.
library;

import 'package:aura_assistant/core/errors/result.dart';
import 'entities/assistant_status.dart';
import 'entities/assistant_invocation.dart';
import 'models/assistant_failure.dart';

/// Service contract for Android default-assistant operations.
abstract class AssistantService {
  /// Check whether this device/platform supports the assistant role,
  /// and whether AURA is the current default.
  ///
  /// Returns [AssistantStatus] on success, or [AssistantFailure] on error.
  Future<Result<AssistantStatus, AssistantFailure>> detectStatus();

  /// Open the Android system assistant-settings activity.
  ///
  /// **Important**: this never silently changes the default assistant —
  /// it always routes the user through the system UI where they must
  /// explicitly choose AURA.
  Future<Result<void, AssistantFailure>> openAssistantSettings();

  /// Retrieve invocation data from the current intent.
  ///
  /// Called when AURA is launched via ACTION_ASSIST to extract
  /// [AssistantInvocation] data from the incoming intent.
  Future<Result<AssistantInvocation, AssistantFailure>>
      getInvocationData();

  /// Check whether the platform supports assistant role at all.
  ///
  /// Lightweight check that does not query the default-assistant setting.
  Future<Result<bool, AssistantFailure>> isAssistantRoleSupported();
}
