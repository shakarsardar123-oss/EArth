/// navigation_tool.dart
/// AURA Assistant – Step 22: Tool Execution System
///
/// NavigationTool — handles navigation/routing interactions.
/// Category: navigation
/// Risk: medium (location access, route changes)
/// Offline: partial (cached maps, navigation needs network)
/// Voice-safe: yes (natural for voice navigation)
///
/// FIX: Implements real GPS location using the existing `geolocator`
/// dependency instead of returning hardcoded lat:0.0, lon:0.0.
/// Handles permission denied, service disabled, and timeout errors.
library;

import 'package:geolocator/geolocator.dart';

import '../../domain/models/tool_input.dart';
import '../../domain/models/tool_output.dart';
import '../../domain/models/tool_execution_context.dart';
import '../../domain/services/tool_interface.dart';

class NavigationTool extends Tool {
  @override
  String get id => 'aura.tool.navigation';

  @override
  String get name => 'Navigation';

  @override
  ToolCategory get category => ToolCategory.navigation;

  @override
  String get description =>
      'Navigate routes, get directions, access location services';

  @override
  String get version => '1.1.0';

  @override
  List<String> get requiredPermissions => [
        'navigation.location',
        'navigation.maps',
      ];

  @override
  ToolRiskLevel get riskLevel => ToolRiskLevel.medium;

  @override
  bool get requiresConfirmation => true; // Location sharing needs confirmation

  @override
  bool get supportsOffline => true; // Cached maps available

  @override
  bool get isVoiceSafe => true; // Voice navigation is primary use case

  @override
  int get defaultTimeoutMs => 15000;

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
          errorMessage: 'Invalid navigation input',
        );
      }

      final action = input.sanitizedParams['action'] as String? ?? 'status';

      switch (action) {
        case 'navigate':
          final destination = input.sanitizedParams['destination'] as String?;
          if (destination == null) {
            return ToolOutput.failure(
              toolId: id,
              errorMessage: 'Destination required for navigation',
            );
          }
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'navigate',
              'destination': destination,
              'status': 'navigating',
            },
          );

        case 'location':
          return await _getRealLocation();

        case 'route':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'route',
              'steps': [],
            },
          );

        case 'nearby':
          return ToolOutput.success(
            toolId: id,
            data: {
              'action': 'nearby',
              'places': [],
            },
          );

        default:
          return ToolOutput.failure(
            toolId: id,
            errorMessage: 'Unknown navigation action: $action',
          );
      }
    } on ToolExecutionCancelledException {
      return ToolOutput.cancelled(toolId: id);
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Navigation error: ${_sanitizeError(e)}',
      );
    } finally {
      _isExecuting = false;
    }
  }

  /// Gets real GPS location using geolocator.
  ///
  /// Handles: permission denied, service disabled, timeout.
  /// Never returns fake 0,0 coordinates.
  Future<ToolOutput> _getRealLocation() async {
    // Step 1: Check if location service is enabled
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Unable to check location service: ${_sanitizeError(e)}',
      );
    }

    if (!serviceEnabled) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Location service is disabled. Please enable GPS in device settings.',
        errorCode: 'SERVICE_DISABLED',
        suggestions: ['Enable GPS in device settings', 'Open location settings from AURA'],
      );
    }

    // Step 2: Check permission status
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Unable to check location permission: ${_sanitizeError(e)}',
      );
    }

    if (permission == LocationPermission.denied) {
      // Request permission
      try {
        permission = await Geolocator.requestPermission();
      } catch (e) {
        return ToolOutput.failure(
          toolId: id,
          errorMessage: 'Unable to request location permission: ${_sanitizeError(e)}',
        );
      }

      if (permission == LocationPermission.denied) {
        return ToolOutput.denied(
          toolId: id,
          reason: 'Location permission was denied by the user',
          errorCode: 'PERMISSION_DENIED',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return ToolOutput.denied(
        toolId: id,
        reason: 'Location permission permanently denied. Please enable in app settings.',
        errorCode: 'PERMISSION_PERMANENTLY_DENIED',
      );
    }

    // Step 3: Get actual position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return ToolOutput.success(
        toolId: id,
        data: {
          'action': 'location',
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'speed': position.speed,
          'timestamp': position.timestamp.toIso8601String(),
        },
      ).copyWith(
        containsSensitiveData: true,
        sensitiveCategories: [SensitiveDataCategory.location],
      );
    } on TimeoutException {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Location request timed out. GPS may be unavailable indoors.',
        errorCode: 'TIMEOUT',
        suggestions: ['Move to an area with better GPS signal', 'Try again later'],
      );
    } catch (e) {
      return ToolOutput.failure(
        toolId: id,
        errorMessage: 'Failed to get location: ${_sanitizeError(e)}',
        errorCode: 'LOCATION_ERROR',
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
  String describe() => 'ئامرازێکی ڕێنمایی بۆ ڕێنمایی، ئاراستە و شوێن'; // Kurdish Sorani

  @override
  void cancel() {}

  String _sanitizeError(Object error) {
    final msg = error.toString();
    if (msg.length > 200) return msg.substring(0, 200);
    return msg;
  }

  static const _validActions = ['navigate', 'location', 'route', 'nearby'];
}
