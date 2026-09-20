// Verifies the confirmation bridge never auto-approves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart'
    show ToolRiskLevel;
import 'package:aura_assistant/core/security/confirmation_guard.dart';
import 'package:aura_assistant/presentation/providers/security_confirmation_provider.dart';
import 'package:aura_assistant/presentation/widgets/security_confirmation_host.dart';

ToolConfirmationRequest _request({
  Duration timeout = const Duration(seconds: 60),
}) {
  return ToolConfirmationRequest(
    toolName: 'delete_alarm',
    arguments: const {'alarm_id': 'a1'},
    riskLevel: ToolRiskLevel.high,
    actionHash: 'hash-1',
    message: 'Delete alarm a1?',
    contextDescription: 'agent requested deletion',
    timeout: timeout,
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: SecurityConfirmationHost(child: Scaffold(body: Text('shell'))),
    ),
  );
}

void main() {
  group('SecurityConfirmationController', () {
    test('denies when the timeout elapses without a decision', () async {
      final controller = SecurityConfirmationController();
      final result = await controller.request(
        _request(timeout: const Duration(milliseconds: 20)),
      );
      expect(result, isFalse);
      controller.dispose();
    });

    test('denies a concurrent second request', () async {
      final controller = SecurityConfirmationController();
      final first = controller.request(_request());
      final second = await controller.request(_request());
      expect(second, isFalse);
      controller.reject();
      expect(await first, isFalse);
      controller.dispose();
    });

    test('denies pending requests on dispose', () async {
      final controller = SecurityConfirmationController();
      final pending = controller.request(_request());
      controller.dispose();
      expect(await pending, isFalse);
    });
  });

  group('SecurityConfirmationHost', () {
    testWidgets('explicit approval resolves to true', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));

      final future = container
          .read(securityConfirmationProvider.notifier)
          .request(_request());
      await tester.pumpAndSettle();

      expect(find.text('Delete alarm a1?'), findsOneWidget);
      await tester.tap(find.text('Allow once'));
      await tester.pumpAndSettle();

      expect(await future, isTrue);
    });

    testWidgets('cancel resolves to false', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));

      final future = container
          .read(securityConfirmationProvider.notifier)
          .request(_request());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await future, isFalse);
    });
  });
}
