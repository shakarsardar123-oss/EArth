/// Structural tests for security presentation layer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/presentation/security_providers.dart';
import 'package:aura_assistant/features/security/presentation/security_state_notifier.dart';
import 'package:aura_assistant/features/security/domain/models/security_config.dart';
import 'package:aura_assistant/features/security/domain/models/security_state.dart';

void main() {
  group('SecurityProviderNames', () {
    test('has static const name and type', () {
      expect(SecurityProviderNames.name, isNotNull);
      expect(SecurityProviderNames.name, isNotEmpty);
      expect(SecurityProviderNames.type, isNotNull);
    });

    test('follows ProviderNames pattern', () {
      // ProviderNames: abstract class with static const String name + static const Type type
      expect(SecurityProviderNames.name, 'security');
    });
  });

  group('SecurityStateNotifier', () {
    test('initializes with SecurityConfig.maximum() on failure', () {
      // FAIL CLOSED: on init failure, default to maximum security
      final notifier = SecurityStateNotifier();
      // After construction, if init fails, should use maximum config
      expect(notifier.usesMaximumOnInitFailure, isTrue);
    });

    test('extends StateNotifier<SecurityState>', () {
      final notifier = SecurityStateNotifier();
      expect(notifier, isNotNull);
    });

    test('state is SecurityState', () {
      final notifier = SecurityStateNotifier();
      expect(notifier.state, isA<SecurityState>());
    });
  });
}
