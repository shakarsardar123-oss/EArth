/// Step 24 — Trigger Authorization Service
///
/// Security gate for all trigger requests.
/// FAIL-CLOSED: every path that is not explicitly authorized → DENY.
/// UNKNOWN = DENY, ERROR = DENY, UNAVAILABLE = DENY.
/// Bridges to Step 15 security adapter for actual policy enforcement.

import '../../domain/entities/trigger_request.dart';
import '../../domain/value_objects/trigger_type.dart';
import '../../domain/repositories/trigger_authorization_repository.dart';

class TriggerAuthorizationService {
  final TriggerAuthorizationRepository _repository;

  TriggerAuthorizationService({
    required TriggerAuthorizationRepository repository,
  }) : _repository = repository;

  /// Authorize a trigger request against security policy.
  /// FAIL-CLOSED: returns denied verdict for any error or unknown state.
  Future<TriggerAuthorizationVerdict> authorize(
    TriggerRequest request,
  ) async {
    // FAIL-CLOSED: unknown type → immediate deny
    if (request.triggerType == TriggerType.unknown) {
      return TriggerAuthorizationVerdict.denied(
        reason: 'trigger_type_unknown',
        policyId: 'fail-closed-unknown-type',
      );
    }

    // FAIL-CLOSED: non-authorizable type → immediate deny
    if (!request.triggerType.isAuthorizable) {
      return TriggerAuthorizationVerdict.denied(
        reason: 'trigger_type_not_authorizable',
        policyId: 'fail-closed-non-authorizable',
      );
    }

    // Check if authorization subsystem is available
    try {
      final available = await _repository.isAvailable();
      if (!available) {
        // FAIL-CLOSED: unavailable → deny
        return TriggerAuthorizationVerdict.denied(
          reason: 'authorization_unavailable',
          policyId: 'fail-closed-unavailable',
        );
      }
    } catch (e) {
      // FAIL-CLOSED: availability check error → deny
      return TriggerAuthorizationVerdict.denied(
        reason: 'authorization_availability_error',
        policyId: 'fail-closed-availability-error',
      );
    }

    // Check if trigger type is permitted by policy
    try {
      final permitted = await _repository.isTriggerTypePermitted(
        request.triggerType,
      );
      if (!permitted) {
        return TriggerAuthorizationVerdict.denied(
          reason: 'trigger_type_not_permitted',
          policyId: 'fail-closed-type-not-permitted',
        );
      }
    } catch (e) {
      // FAIL-CLOSED: policy check error → deny
      return TriggerAuthorizationVerdict.denied(
        reason: 'policy_check_error',
        policyId: 'fail-closed-policy-error',
      );
    }

    // Full authorization check
    try {
      final verdict = await _repository.authorize(request);
      return verdict;
    } catch (e) {
      // FAIL-CLOSED: authorization error → deny
      return TriggerAuthorizationVerdict.denied(
        reason: 'authorization_error',
        policyId: 'fail-closed-auth-error',
      );
    }
  }
}
