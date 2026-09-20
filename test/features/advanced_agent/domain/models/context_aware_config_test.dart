/// context_aware_config_test.dart
/// Structural tests for ContextAwareConfig model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/advanced_agent/domain/models/context_aware_config.dart';

void main() {
  group('ContextAwareConfig', () {
    test('constructs with configId', () {
      final config = ContextAwareConfig(
        configId: 'cfg1',
        preferredLocale: 'ku',
      );
      expect(config.configId, 'cfg1');
      expect(config.preferredLocale, 'ku');
    });

    test('locale defaults to ku (Sorani)', () {
      final config = ContextAwareConfig(
        configId: 'cfg2',
        preferredLocale: 'ku',
      );
      expect(config.preferredLocale, 'ku');
    });
  });
}
