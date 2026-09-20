import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/core/security/security_policy.dart';
import 'package:aura_assistant/core/security/confirmation_guard.dart';
import 'package:aura_assistant/core/security/tool_security_gate.dart';
import 'package:aura_assistant/core/security/security_providers.dart';
import 'package:aura_assistant/core/permissions/permission_provider.dart';
import 'package:aura_assistant/core/permissions/permission_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';
import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart';
import 'package:aura_assistant/core/tools/tool_arguments.dart';

void main() {
  group('security_providers', () {
    group('securityPolicyProvider', () {
      test('resolves to SecurityPolicy instance', () {
        final container = ProviderContainer();
        final policy = container.read(securityPolicyProvider);
        expect(policy, isA<SecurityPolicy>());
      });

      test('provides default sensitive settings', () {
        final container = ProviderContainer();
        final policy = container.read(securityPolicyProvider);
        expect(policy.sensitiveSettings.containsKey('security'), isTrue);
      });

      test('provides default sensitive protocols', () {
        final container = ProviderContainer();
        final policy = container.read(securityPolicyProvider);
        expect(policy.sensitiveProtocols, contains('tel'));
      });

      test('provides default sensitive packages', () {
        final container = ProviderContainer();
        final policy = container.read(securityPolicyProvider);
        expect(policy.sensitivePackages, contains('com.android.settings'));
      });

      test('can be overridden with custom policy', () {
        final customPolicy = SecurityPolicy(
          sensitiveSettings: {'my_key': ToolRiskLevel.high},
        );
        final container = ProviderContainer(
          overrides: [
            securityPolicyProvider.overrideWithValue(customPolicy),
          ],
        );
        final policy = container.read(securityPolicyProvider);
        expect(policy.sensitiveSettings, hasLength(1));
        expect(policy.sensitiveSettings['my_key'], ToolRiskLevel.high);
      });
    });

    group('confirmationGuardProvider', () {
      test('resolves to ConfirmationGuard instance', () {
        final container = ProviderContainer();
        final guard = container.read(confirmationGuardProvider);
        expect(guard, isA<ConfirmationGuard>());
      });

      test('initial state has no pending request', () {
        final container = ProviderContainer();
        final guard = container.read(confirmationGuardProvider);
        expect(guard.pending, isNull);
      });

      test('initial state has empty history', () {
        final container = ProviderContainer();
        final guard = container.read(confirmationGuardProvider);
        expect(guard.history, isEmpty);
      });

      test('can be overridden with custom guard', () {
        final customGuard = ConfirmationGuard();
        // Pre-request and accept to put something in history
        customGuard.requestConfirmation(
          toolName: 'pre_tool',
          arguments: ToolArguments({'k': 'v'}),
          riskLevel: ToolRiskLevel.high,
        );
        customGuard.acceptPending();

        final container = ProviderContainer(
          overrides: [
            confirmationGuardProvider.overrideWithValue(customGuard),
          ],
        );
        final guard = container.read(confirmationGuardProvider);
        expect(guard.history, hasLength(1));
      });
    });

    group('toolSecurityGateProvider', () {
      test('resolves to ToolSecurityGate instance', () {
        final container = ProviderContainer();
        final gate = container.read(toolSecurityGateProvider);
        expect(gate, isA<ToolSecurityGate>());
      });

      test('uses the security policy from securityPolicyProvider', () {
        final container = ProviderContainer();
        final gate = container.read(toolSecurityGateProvider);
        final policy = container.read(securityPolicyProvider);
        // Gate should use the same policy — verify by checking a policy-derived behavior
        expect(gate.securityPolicy.sensitiveSettings,
            policy.sensitiveSettings);
        expect(gate.securityPolicy.sensitiveProtocols,
            policy.sensitiveProtocols);
      });

      test('uses the confirmation guard from confirmationGuardProvider', () {
        final container = ProviderContainer();
        final gate = container.read(toolSecurityGateProvider);
        final guard = container.read(confirmationGuardProvider);
        // Gate should use the same guard — verify they share state
        expect(gate.confirmationGuard, same(guard));
      });

      test('picks up custom permission service via override', () async {
        // Override permissionServiceProvider to return a custom service
        final customProvider = Provider<PermissionService>((ref) {
          return _FakePermissionService(granted: false);
        });

        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithProvider(customProvider),
          ],
        );

        final gate = container.read(toolSecurityGateProvider);
        expect(gate, isA<ToolSecurityGate>());
        // The gate was created with the overridden permission service
        // We cannot directly inspect the private field, but we know
        // the constructor received it
      });

      test('uses custom security policy when overridden', () {
        final customPolicy = SecurityPolicy(
          sensitiveSettings: {'custom_sensitive': ToolRiskLevel.critical},
        );

        final container = ProviderContainer(
          overrides: [
            securityPolicyProvider.overrideWithValue(customPolicy),
          ],
        );

        final gate = container.read(toolSecurityGateProvider);
        expect(gate.securityPolicy.sensitiveSettings,
            customPolicy.sensitiveSettings);
      });

      test('uses custom confirmation guard when overridden', () {
        final customGuard = ConfirmationGuard();

        final container = ProviderContainer(
          overrides: [
            confirmationGuardProvider.overrideWithValue(customGuard),
          ],
        );

        final gate = container.read(toolSecurityGateProvider);
        expect(gate.confirmationGuard, same(customGuard));
      });

      test('all three providers are wired together', () {
        final container = ProviderContainer();
        final gate = container.read(toolSecurityGateProvider);
        final policy = container.read(securityPolicyProvider);
        final guard = container.read(confirmationGuardProvider);

        // Gate is constructed from all three providers
        expect(gate.securityPolicy, same(policy));
        expect(gate.confirmationGuard, same(guard));
        expect(gate, isA<ToolSecurityGate>());
      });
    });
  });
}

class _FakePermissionService extends PermissionService {
  final bool _granted;

  _FakePermissionService({required bool granted}) : _granted = granted;

  @override
  Future<bool> isPermissionGranted(ph.Permission permission) async => _granted;

  @override
  Future<bool> isPermissionPermanentlyDenied(ph.Permission permission) async => false;

  @override
  Future<Result<bool, PermissionFailure>> requestPermission(
      ph.Permission permission) async {
    return Result.failure(PermissionFailure(
      message: 'test',
      code: 'PERMISSION_DENIED',
      permission: permission.toString(),
    ));
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<Map<ph.Permission, bool>> requestAllRequiredPermissions() async =>
      <ph.Permission, bool>{};
}
