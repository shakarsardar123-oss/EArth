/// Step 24 — Trigger Authorization Service Tests
///
/// Structural tests for TriggerAuthorizationService.
/// FAIL-CLOSED: unknown→denied, unavailable→denied, error→denied.
/// No Flutter/Dart SDK — structural validation only, NEVER claim runtime test results.

import 'package:aura_assistant/features/trigger_integration/domain/entities/trigger_request.dart';
import 'package:aura_assistant/features/trigger_integration/domain/value_objects/trigger_type.dart';
import 'package:aura_assistant/features/trigger_integration/domain/repositories/trigger_authorization_repository.dart';
import 'package:aura_assistant/features/trigger_integration/application/authorization/trigger_authorization_service.dart';

/// Mock repo: always authorizes
class _AlwaysAuthorizeRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    return TriggerAuthorizationVerdict.authorized(
      reason: 'mock_ok', policyId: 'policy-001',
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async => true;
}

/// Mock repo: always denies type permission
class _DenyTypeRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    return TriggerAuthorizationVerdict.denied(
      reason: 'type_not_permitted', policyId: 'policy-002',
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async => false;
}

/// Mock repo: unavailable
class _UnavailableRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    return TriggerAuthorizationVerdict.denied(
      reason: 'service_unavailable', policyId: 'policy-003',
    );
  }

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async => true;
}

/// Mock repo: throws on auth
class _ErrorRepo implements TriggerAuthorizationRepository {
  @override
  Future<TriggerAuthorizationVerdict> authorize(TriggerRequest request) async {
    throw Exception('auth_service_crash');
  }

  @override
  Future<bool> isAvailable() async => throw Exception('availability_check_crash');

  @override
  Future<bool> isTriggerTypePermitted(TriggerType type) async =>
      throw Exception('type_check_crash');
}

void main() {
  group('TriggerAuthorizationService', () {
    test('authorizes valid request with available repo', () async {
      final repo = _AlwaysAuthorizeRepo();
      final service = TriggerAuthorizationService(authorizationRepository: repo);
      final request = TriggerRequest(
        requestId: 'auth-001',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final verdict = await service.authorize(request);
      expect(verdict.authorized, isTrue);
    });

    test('FAIL-CLOSED: denies unknown trigger type', () async {
      final repo = _AlwaysAuthorizeRepo();
      final service = TriggerAuthorizationService(authorizationRepository: repo);
      final request = TriggerRequest(
        requestId: 'auth-002',
        triggerType: TriggerType.unknown,
        source: 'unknown',
        timestamp: DateTime.now(),
      );
      final verdict = await service.authorize(request);
      expect(verdict.authorized, isFalse);
    });

    test('FAIL-CLOSED: denies when authorization unavailable', () async {
      final repo = _UnavailableRepo();
      final service = TriggerAuthorizationService(authorizationRepository: repo);
      final request = TriggerRequest(
        requestId: 'auth-003',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final verdict = await service.authorize(request);
      expect(verdict.authorized, isFalse);
    });

    test('FAIL-CLOSED: denies when trigger type not permitted', () async {
      final repo = _DenyTypeRepo();
      final service = TriggerAuthorizationService(authorizationRepository: repo);
      final request = TriggerRequest(
        requestId: 'auth-004',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final verdict = await service.authorize(request);
      expect(verdict.authorized, isFalse);
    });

    test('FAIL-CLOSED: denies when repo throws error', () async {
      final repo = _ErrorRepo();
      final service = TriggerAuthorizationService(authorizationRepository: repo);
      final request = TriggerRequest(
        requestId: 'auth-005',
        triggerType: TriggerType.quickSettings,
        source: 'qs',
        timestamp: DateTime.now(),
      );
      final verdict = await service.authorize(request);
      expect(verdict.authorized, isFalse);
    });

    test('FAIL-CLOSED: denies unauthorizable type even with authorizing repo', () async {
      final repo = _AlwaysAuthorizeRepo();
      final service = TriggerAuthorizationService(authorizationRepository: repo);
      final request = TriggerRequest(
        requestId: 'auth-006',
        triggerType: TriggerType.unknown,
        source: 'unknown',
        timestamp: DateTime.now(),
      );
      final verdict = await service.authorize(request);
      expect(verdict.authorized, isFalse);
    });
  });
}
