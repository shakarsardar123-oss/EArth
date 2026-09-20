/// api_reliability_domain_test.dart
/// Step 27 structural validation — API Reliability domain layer.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('API Reliability Domain', () {
    test('CircuitBreakerState.unknown.isDenied is true', () {
      expect(CircuitBreakerState.unknown.isDenied, isTrue);
    });

    test('BudgetVerdict.unknown.isDenied is true', () {
      expect(BudgetVerdict.unknown.isDenied, isTrue);
    });

    test('ApiGatewayResult.denied is denied', () {
      expect(ApiGatewayResult.denied.isDenied, isTrue);
    });
  });
}
