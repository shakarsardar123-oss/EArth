// Test file for presentation-layer assistant_providers.
//
// Structural tests — verify presentation provider name constants
// and factory function typedefs are correctly defined.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/assistant_integration/presentation/assistant_providers.dart';

void main() {
  group('PresentationAssistantProviders', () {
    test('statusProviderName is non-empty string', () {
      expect(PresentationAssistantProviders.statusProviderName, isA<String>());
      expect(PresentationAssistantProviders.statusProviderName, isNotEmpty);
    });

    test('invocationProviderName is non-empty string', () {
      expect(PresentationAssistantProviders.invocationProviderName, isA<String>());
      expect(PresentationAssistantProviders.invocationProviderName, isNotEmpty);
    });

    test('stateProviderName is non-empty string', () {
      expect(PresentationAssistantProviders.stateProviderName, isA<String>());
      expect(PresentationAssistantProviders.stateProviderName, isNotEmpty);
    });

    test('canRequestDefaultProviderName is non-empty string', () {
      expect(PresentationAssistantProviders.canRequestDefaultProviderName, isA<String>());
      expect(PresentationAssistantProviders.canRequestDefaultProviderName, isNotEmpty);
    });

    test('provider name constants follow naming convention', () {
      final names = [
        PresentationAssistantProviders.statusProviderName,
        PresentationAssistantProviders.invocationProviderName,
        PresentationAssistantProviders.stateProviderName,
        PresentationAssistantProviders.canRequestDefaultProviderName,
      ];
      for (final name in names) {
        expect(name.toLowerCase(), contains('assistant'));
      }
    });

    test('all provider names are unique', () {
      final names = [
        PresentationAssistantProviders.statusProviderName,
        PresentationAssistantProviders.invocationProviderName,
        PresentationAssistantProviders.stateProviderName,
        PresentationAssistantProviders.canRequestDefaultProviderName,
      ];
      expect(names.toSet().length, equals(names.length));
    });
  });
}
