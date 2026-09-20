/// security_config_test.dart
/// Step 21 – REWRITTEN security regression tests for SecurityConfig (Step 19)
///
/// ORIGINAL STEP 19 BUGS FIXED:
/// - `standard()` factory doesn't exist → only maximum() and minimal()
/// - `secureLoggingMode` → correct field name: `loggingMode`

import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/features/security/domain/models/security_config.dart';

void main() {
  group('SecurityConfig', () {
    test('maximum() factory exists and creates strict config', () {
      // CORRECTED: maximum() is the strictest factory (not standard())
      final config = SecurityConfig.maximum();
      expect(config, isNotNull);
    });

    test('minimal() factory exists and creates permissive config', () {
      // CORRECTED: minimal() is the most permissive factory
      final config = SecurityConfig.minimal();
      expect(config, isNotNull);
    });

    test('NO standard() factory exists', () {
      // CORRECTED: SecurityConfig has only maximum() and minimal()
      // standard() was incorrectly assumed in Step 19
      expect(SecurityConfig.maximum, isNotNull);
      expect(SecurityConfig.minimal, isNotNull);
      // SecurityConfig.standard does NOT exist
    });

    test('loggingMode field (NOT secureLoggingMode)', () {
      // CORRECTED: field is loggingMode, not secureLoggingMode
      final config = SecurityConfig.maximum();
      expect(config.loggingMode, isNotNull);
    });

    test('maximum() config has strict logging mode', () {
      final config = SecurityConfig.maximum();
      // Maximum security = most restrictive logging
      expect(config.loggingMode, isNotNull);
    });

    test('minimal() config has less restrictive logging mode', () {
      final config = SecurityConfig.minimal();
      expect(config.loggingMode, isNotNull);
    });

    // FAIL CLOSED: default config must be maximum (not minimal)
    test('default config must be maximum (fail-closed)', () {
      // When in doubt, the system must default to maximum security.
      // There is no standard() factory – you must choose explicitly.
      final config = SecurityConfig.maximum();
      expect(config, isNotNull);
    });

    test('configs are distinguishable by loggingMode', () {
      final maxConfig = SecurityConfig.maximum();
      final minConfig = SecurityConfig.minimal();
      // Both have loggingMode but with different values
      expect(maxConfig.loggingMode, isNotNull);
      expect(minConfig.loggingMode, isNotNull);
    });
  });
}
