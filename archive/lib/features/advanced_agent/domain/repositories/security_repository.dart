/// security_repository.dart
/// AURA Assistant – Step 25: Adapter target for Step 19 SecurityRepository
///
/// Exact signature match from Step 23.
/// This interface MUST be implemented by Step19SecurityAdapter.
library;

import '../models/safety_verdict.dart';

/// Abstract repository matching Step 23's SecurityRepository.
/// check(action, toolId, riskLevel) → SecurityVerdict
/// isAvailable() → bool
///
/// Note: Step 23's SecurityVerdict has allowed=false default, denied()/allowed()
/// factories. Our SafetyVerdict is the Step 25 domain model. The adapter will
/// convert between the two.
abstract class SecurityRepository {
  Future<SafetyVerdict> check(
    String action,
    String toolId,
    String riskLevel,
  );
  bool isAvailable();
}
