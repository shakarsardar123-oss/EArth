/// Riverpod providers for the AURA security system.
///
/// Wires together [SecurityPolicy], [ConfirmationGuard], and
/// [ToolSecurityGate] with the existing [permissionServiceProvider]
/// so they can be injected into [AgentExecutor] without breaking
/// Phase 1–6 code.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'security_policy.dart';
import 'confirmation_guard.dart';
import 'tool_security_gate.dart';
import '../permissions/permission_provider.dart';

/// Provides the default [SecurityPolicy] instance.
///
/// Uses all built-in sensitive-key / URL-protocol / package-prefix
/// registries. Override in a [ProviderScope] for tests or custom policy.
final securityPolicyProvider = Provider<SecurityPolicy>((ref) {
  return SecurityPolicy();
});

/// Provides the [ConfirmationGuard] instance.
///
/// Stateless by default — confirmation state lives inside the guard.
/// Override in a [ProviderScope] for tests that need spy/fake guards.
final confirmationGuardProvider = Provider<ConfirmationGuard>((ref) {
  return ConfirmationGuard();
});

/// Provides the [ToolSecurityGate] wired to all dependencies.
///
/// Watches [permissionServiceProvider], [securityPolicyProvider],
/// and [confirmationGuardProvider] so the gate is always consistent
/// with the current provider state.
final toolSecurityGateProvider = Provider<ToolSecurityGate>((ref) {
  final permissionService = ref.watch(permissionServiceProvider);
  final securityPolicy = ref.watch(securityPolicyProvider);
  final confirmationGuard = ref.watch(confirmationGuardProvider);
  return ToolSecurityGate(
    permissionService: permissionService,
    securityPolicy: securityPolicy,
    confirmationGuard: confirmationGuard,
  );
});
