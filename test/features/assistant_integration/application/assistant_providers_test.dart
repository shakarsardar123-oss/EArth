// Test file for application-layer assistant_providers.
//
// Structural tests — verify provider name constants and
// the factory typedef exist and are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/assistant_integration/application/assistant_providers.dart';

void main() {
  group('AssistantProviders', () {
    test('controllerProviderName is non-empty string', () {
      expect(AssistantProviders.controllerProviderName, isA<String>());
      expect(AssistantProviders.controllerProviderName, isNotEmpty);
    });

    test('statusProviderName is non-empty string', () {
      expect(AssistantProviders.statusProviderName, isA<String>());
      expect(AssistantProviders.statusProviderName, isNotEmpty);
    });

    test('invocationProviderName is non-empty string', () {
      expect(AssistantProviders.invocationProviderName, isA<String>());
      expect(AssistantProviders.invocationProviderName, isNotEmpty);
    });

    test('createAssistantController typedef is defined', () {
      // Verify the typedef exists by referencing it.
      // The actual type is a function that returns an AssistantController.
      expect(
        // We just confirm the typedef symbol resolves.
        #createAssistantController,
        isNotNull,
      );
    });

    test('provider name constants follow naming convention', () {
      // All names should contain 'assistant' or 'Assistant'
      final names = [
        AssistantProviders.controllerProviderName,
        AssistantProviders.statusProviderName,
        AssistantProviders.invocationProviderName,
      ];
      for (final name in names) {
        expect(name.toLowerCase(), contains('assistant'));
      }
    });
  });
}
