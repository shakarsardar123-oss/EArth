/// Hand-written fake [SecurityPolicy] for voice-screen engine tests.
library;

import 'package:aura_assistant/core/security/security_policy.dart';

/// Configuration for [FakeSecurityPolicy].
class FakeSecurityConfig {
  /// The list of violations to return from [checkSecurityBoundaries].
  /// If empty (default), no violations are reported — all clear.
  final List<SecurityBoundaryViolation> violations;

  const FakeSecurityConfig({
    this.violations = const [],
  });
}

/// A fake [SecurityPolicy] that extends the concrete class
/// and overrides [checkSecurityBoundaries] for test control.
///
/// - Call [configure] before each test to set up expected outcomes.
/// - Tracks call counts and last arguments for assertions.
class FakeSecurityPolicy extends SecurityPolicy {
  FakeSecurityConfig _config = const FakeSecurityConfig();

  /// Call counts for verification.
  int checkSecurityBoundariesCallCount = 0;

  /// Last arguments for verification.
  bool? lastAttemptsShellExec;
  bool? lastAttemptsArbitraryPackage;
  bool? lastAttemptsIntentAbuse;
  bool? lastAttemptsPermissionBypass;
  bool? lastAttemptsAccessibilityAbuse;
  bool? lastAttemptsHiddenBackgroundAction;
  bool? lastAttemptsSecurityBypass;
  bool? lastAttemptsSilentSensitiveAction;

  FakeSecurityPolicy() : super();

  /// Configure the fake's behaviour.
  void configure(FakeSecurityConfig config) {
    _config = config;
  }

  @override
  List<SecurityBoundaryViolation> checkSecurityBoundaries({
    bool? attemptsShellExec,
    bool? attemptsArbitraryPackage,
    bool? attemptsIntentAbuse,
    bool? attemptsPermissionBypass,
    bool? attemptsAccessibilityAbuse,
    bool? attemptsHiddenBackgroundAction,
    bool? attemptsSecurityBypass,
    bool? attemptsSilentSensitiveAction,
  }) {
    checkSecurityBoundariesCallCount++;
    lastAttemptsShellExec = attemptsShellExec;
    lastAttemptsArbitraryPackage = attemptsArbitraryPackage;
    lastAttemptsIntentAbuse = attemptsIntentAbuse;
    lastAttemptsPermissionBypass = attemptsPermissionBypass;
    lastAttemptsAccessibilityAbuse = attemptsAccessibilityAbuse;
    lastAttemptsHiddenBackgroundAction = attemptsHiddenBackgroundAction;
    lastAttemptsSecurityBypass = attemptsSecurityBypass;
    lastAttemptsSilentSensitiveAction = attemptsSilentSensitiveAction;

    return _config.violations;
  }
}
