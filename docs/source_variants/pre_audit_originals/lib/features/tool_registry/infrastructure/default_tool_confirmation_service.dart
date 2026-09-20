/// default_tool_confirmation_service.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Concrete implementation of [ToolConfirmationService].
///
/// Default implementation that:
/// - Always denies when unavailable (FAIL CLOSED)
/// - Can be configured with auto-confirmation policies for testing
/// - Supports a timeout mechanism
library;

import 'package:aura_assistant/features/tool_registry/domain/models/models.dart';
import 'package:aura_assistant/features/tool_registry/domain/services/services.dart';

/// Concrete implementation of [ToolConfirmationService].
///
/// FAIL CLOSED: if unavailable, returns [ConfirmationResult.unavailable].
/// FAIL CLOSED: if the tool's policy is unknown, returns denied.
class DefaultToolConfirmationService implements ToolConfirmationService {
  /// Whether the confirmation service is available.
  bool _isAvailable = true;

  /// Duration before a confirmation request times out.
  final Duration _timeout;

  /// Whether to auto-confirm [ConfirmationPolicy.never] tools.
  ///
  /// These tools never need confirmation, so they are auto-confirmed.
  final bool _autoConfirmNever;

  /// Whether to auto-deny [ConfirmationPolicy.always] tools in headless mode.
  final bool _headlessMode;

  /// Callback for showing the actual confirmation dialog to the user.
  ///
  /// If null, the service will use its default behavior.
  final Future<ConfirmationResult> Function(
    ToolDefinition definition,
    String? message,
  )? _showConfirmationCallback;

  DefaultToolConfirmationService({
    bool isAvailable = true,
    Duration timeout = const Duration(seconds: 30),
    bool autoConfirmNever = true,
    bool headlessMode = false,
    Future<ConfirmationResult> Function(
      ToolDefinition definition,
      String? message,
    )? showConfirmationCallback,
  })  : _isAvailable = isAvailable,
        _timeout = timeout,
        _autoConfirmNever = autoConfirmNever,
        _headlessMode = headlessMode,
        _showConfirmationCallback = showConfirmationCallback;

  @override
  Future<ConfirmationResult> requestConfirmation(
    ToolDefinition definition, {\n    String? message,
  }) async {
    // FAIL CLOSED: if unavailable, return unavailable.
    if (!_isAvailable) {
      return ConfirmationResult.unavailable;
    }

    final policy = definition.effectiveConfirmationPolicy;

    // Policy: never → auto-confirm.
    if (policy == ConfirmationPolicy.never) {
      if (_autoConfirmNever) {
        return ConfirmationResult.confirmed;
      }
      // If auto-confirm-never is disabled, still confirm (never means never).
      return ConfirmationResult.confirmed;
    }

    // FAIL CLOSED: Policy: unknown → deny.
    if (policy == ConfirmationPolicy.unknown) {
      return ConfirmationResult.denied;
    }

    // Policy: always → must always get confirmation.
    if (policy == ConfirmationPolicy.always) {
      if (_headlessMode) {
        // In headless mode, we cannot show a dialog, so deny.
        return ConfirmationResult.denied;
      }
      return _askUser(definition, message);
    }

    // Policy: whenSensitive → check if sensitive.
    if (policy == ConfirmationPolicy.whenSensitive) {
      if (definition.accessesSensitiveData || definition.isDangerous) {
        if (_headlessMode) {
          return ConfirmationResult.denied;
        }
        return _askUser(definition, message);
      }
      // Not sensitive → auto-confirm.
      return ConfirmationResult.confirmed;
    }

    // FAIL CLOSED: any unrecognized policy → deny.
    return ConfirmationResult.denied;
  }

  /// Ask the user for confirmation.
  Future<ConfirmationResult> _askUser(
    ToolDefinition definition,
    String? message,
  ) async {
    // If a callback is provided, use it.
    if (_showConfirmationCallback != null) {
      try {
        final result = await _showConfirmationCallback(
          definition,
          message,
        ).timeout(_timeout);
        return result;
      } catch (e) {
        // Timeout or error → fail closed.
        if (e.toString().contains('TimeoutException') ||
            e.toString().toLowerCase().contains('timed out')) {
          return ConfirmationResult.timedOut;
        }
        return ConfirmationResult.denied;
      }
    }

    // Default: no UI → deny (fail closed).
    // In a real app, this would show a dialog.
    return ConfirmationResult.denied;
  }

  @override
  bool get isAvailable => _isAvailable;

  /// Set availability.
  void setAvailable(bool available) => _isAvailable = available;

  /// Set headless mode.
  void setHeadlessMode(bool headless) => _headlessMode = headless;
}
