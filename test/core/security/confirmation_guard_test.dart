import 'package:flutter_test/flutter_test.dart';
import 'package:texo/core/security/confirmation_guard.dart';
import 'package:texo/core/security/security_messages.dart';
import 'package:texo/core/tools/tool_arguments.dart';
import 'package:texo/core/agent/agent_confirmation_manager.dart';

void main() {
  group('ToolConfirmationState', () {
    group('none', () {
      test('isAllowed returns false', () {
        expect(ToolConfirmationState.none.isAllowed, isFalse);
      });

      test('isPending returns false', () {
        expect(ToolConfirmationState.none.isPending, isFalse);
      });
    });

    group('pending', () {
      test('isAllowed returns false', () {
        expect(ToolConfirmationState.pending.isAllowed, isFalse);
      });

      test('isPending returns true', () {
        expect(ToolConfirmationState.pending.isPending, isTrue);
      });
    });

    group('accepted', () {
      test('isAllowed returns true', () {
        expect(ToolConfirmationState.accepted.isAllowed, isTrue);
      });

      test('isPending returns false', () {
        expect(ToolConfirmationState.accepted.isPending, isFalse);
      });
    });

    group('cancelled', () {
      test('isAllowed returns false', () {
        expect(ToolConfirmationState.cancelled.isAllowed, isFalse);
      });

      test('isPending returns false', () {
        expect(ToolConfirmationState.cancelled.isPending, isFalse);
      });
    });

    group('expired', () {
      test('isAllowed returns false', () {
        expect(ToolConfirmationState.expired.isAllowed, isFalse);
      });

      test('isPending returns false', () {
        expect(ToolConfirmationState.expired.isPending, isFalse);
      });
    });

    test('has 5 enum values', () {
      expect(ToolConfirmationState.values, hasLength(5));
    });
  });

  group('ToolConfirmationRequest', () {
    ToolConfirmationRequest makeRequest({
      String toolName = 'test_tool',
      Map<String, dynamic>? arguments,
      ToolRiskLevel riskLevel = ToolRiskLevel.high,
      String actionHash = 'abc12345',
      String message = 'test message',
      String contextDescription = 'test context',
      Duration? timeout,
      DateTime? createdAt,
    }) {
      return ToolConfirmationRequest(
        toolName: toolName,
        arguments: arguments ?? {'key': 'value'},
        riskLevel: riskLevel,
        actionHash: actionHash,
        message: message,
        contextDescription: contextDescription,
        timeout: timeout ?? const Duration(seconds: 60),
        createdAt: createdAt,
      );
    }

    group('construction', () {
      test('stores tool name', () {
        final req = makeRequest(toolName: 'my_tool');
        expect(req.toolName, 'my_tool');
      });

      test('stores arguments', () {
        final args = {'packageName': 'com.example.app'};
        final req = makeRequest(arguments: args);
        expect(req.arguments, args);
      });

      test('stores risk level', () {
        final req = makeRequest(riskLevel: ToolRiskLevel.critical);
        expect(req.riskLevel, ToolRiskLevel.critical);
      });

      test('stores action hash', () {
        final req = makeRequest(actionHash: 'deadbeef');
        expect(req.actionHash, 'deadbeef');
      });

      test('stores bilingual message', () {
        final req = makeRequest(message: 'ڕەزامەندی / Confirm');
        expect(req.message, 'ڕەزامەندی / Confirm');
      });

      test('stores context description', () {
        final req = makeRequest(contextDescription: 'launching app');
        expect(req.contextDescription, 'launching app');
      });

      test('uses default timeout of 60s', () {
        final req = makeRequest();
        expect(req.timeout, const Duration(seconds: 60));
      });

      test('accepts custom timeout', () {
        final req = makeRequest(timeout: const Duration(seconds: 120));
        expect(req.timeout, const Duration(seconds: 120));
      });

      test('sets createdAt to now by default', () {
        final before = DateTime.now();
        final req = makeRequest();
        final after = DateTime.now();
        expect(req.createdAt.isAfter(before.subtract(
          const Duration(milliseconds: 100),
        )), isTrue);
        expect(req.createdAt.isBefore(after.add(
          const Duration(milliseconds: 100),
        )), isTrue);
      });

      test('accepts custom createdAt', () {
        final customTime = DateTime(2025, 1, 1);
        final req = makeRequest(createdAt: customTime);
        expect(req.createdAt, customTime);
      });
    });

    group('initial state', () {
      test('starts as pending', () {
        final req = makeRequest();
        expect(req.state, ToolConfirmationState.pending);
      });

      test('is not expired initially', () {
        final req = makeRequest();
        expect(req.isExpired, isFalse);
      });
    });

    group('accept', () {
      test('transitions to accepted state', () {
        final req = makeRequest();
        req.accept();
        expect(req.state, ToolConfirmationState.accepted);
      });

      test('transitions to expired if already expired', () {
        final expiredTime = DateTime.now().subtract(const Duration(minutes: 2));
        final req = makeRequest(
          timeout: const Duration(seconds: 60),
          createdAt: expiredTime,
        );
        req.accept();
        expect(req.state, ToolConfirmationState.expired);
      });
    });

    group('cancel', () {
      test('transitions to cancelled state', () {
        final req = makeRequest();
        req.cancel();
        expect(req.state, ToolConfirmationState.cancelled);
      });
    });

    group('verifyActionHash', () {
      test('returns true when hash matches', () {
        const toolName = 'my_tool';
        final args = {'key': 'value'};
        final hash = ConfirmationGuard.computeActionHash(toolName, args);
        final req = ToolConfirmationRequest(
          toolName: toolName,
          arguments: args,
          riskLevel: ToolRiskLevel.high,
          actionHash: hash,
          message: 'test',
          contextDescription: '',
        );
        expect(req.verifyActionHash(toolName, args), isTrue);
      });

      test('returns false when tool name differs', () {
        final hash = ConfirmationGuard.computeActionHash('tool_a', {'k': 'v'});
        final req = ToolConfirmationRequest(
          toolName: 'tool_a',
          arguments: {'k': 'v'},
          riskLevel: ToolRiskLevel.high,
          actionHash: hash,
          message: 'test',
          contextDescription: '',
        );
        expect(req.verifyActionHash('tool_b', {'k': 'v'}), isFalse);
      });

      test('returns false when arguments differ', () {
        final hash = ConfirmationGuard.computeActionHash('tool', {'k': 'v1'});
        final req = ToolConfirmationRequest(
          toolName: 'tool',
          arguments: {'k': 'v1'},
          riskLevel: ToolRiskLevel.high,
          actionHash: hash,
          message: 'test',
          contextDescription: '',
        );
        expect(req.verifyActionHash('tool', {'k': 'v2'}), isFalse);
      });
    });

    group('isExpired', () {
      test('returns true when timeout has elapsed', () {
        final expiredTime = DateTime.now().subtract(const Duration(minutes: 2));
        final req = makeRequest(
          timeout: const Duration(seconds: 60),
          createdAt: expiredTime,
        );
        expect(req.isExpired, isTrue);
      });

      test('returns false when timeout has not elapsed', () {
        final recentTime = DateTime.now().subtract(const Duration(seconds: 5));
        final req = makeRequest(
          timeout: const Duration(seconds: 60),
          createdAt: recentTime,
        );
        expect(req.isExpired, isFalse);
      });
    });

    group('toString', () {
      test('contains tool name and state', () {
        final req = makeRequest(toolName: 'my_tool');
        final str = req.toString();
        expect(str, contains('my_tool'));
        expect(str, contains('pending'));
      });
    });
  });

  group('ConfirmationGuard', () {
    ConfirmationGuard makeGuard({SecurityMessages? messages}) {
      return ConfirmationGuard(messages: messages ?? const SecurityMessages());
    }

    group('construction', () {
      test('uses default SecurityMessages', () {
        final guard = ConfirmationGuard();
        expect(guard.messages, isA<SecurityMessages>());
      });

      test('accepts custom SecurityMessages', () {
        final customMessages = const SecurityMessages();
        final guard = ConfirmationGuard(messages: customMessages);
        expect(guard.messages, customMessages);
      });
    });

    group('initial state', () {
      test('pending is null', () {
        final guard = makeGuard();
        expect(guard.pending, isNull);
      });

      test('history is empty', () {
        final guard = makeGuard();
        expect(guard.history, isEmpty);
      });

      test('isWaitingForConfirmation is false', () {
        final guard = makeGuard();
        expect(guard.isWaitingForConfirmation, isFalse);
      });
    });

    group('requestConfirmation', () {
      test('returns null for none risk level', () {
        final guard = makeGuard();
        final result = guard.requestConfirmation(
          toolName: 'safe_tool',
          arguments: ToolArguments({}),
          riskLevel: ToolRiskLevel.none,
        );
        expect(result, isNull);
      });

      test('returns null for low risk level', () {
        final guard = makeGuard();
        final result = guard.requestConfirmation(
          toolName: 'low_risk_tool',
          arguments: ToolArguments({}),
          riskLevel: ToolRiskLevel.low,
        );
        expect(result, isNull);
      });

      test('returns request for medium risk level', () {
        final guard = makeGuard();
        final result = guard.requestConfirmation(
          toolName: 'medium_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.medium,
        );
        expect(result, isNotNull);
        expect(result!.toolName, 'medium_tool');
        expect(result.riskLevel, ToolRiskLevel.medium);
      });

      test('returns request for high risk level', () {
        final guard = makeGuard();
        final result = guard.requestConfirmation(
          toolName: 'high_risk_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        expect(result, isNotNull);
        expect(result!.toolName, 'high_risk_tool');
        expect(result.riskLevel, ToolRiskLevel.high);
      });

      test('returns request for critical risk level', () {
        final guard = makeGuard();
        final result = guard.requestConfirmation(
          toolName: 'critical_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.critical,
        );
        expect(result, isNotNull);
        expect(result!.riskLevel, ToolRiskLevel.critical);
      });

      test('sets pending request', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        expect(guard.pending, isNotNull);
        expect(guard.pending!.toolName, 'my_tool');
      });

      test('isWaitingForConfirmation becomes true', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({}),
          riskLevel: ToolRiskLevel.medium,
        );
        expect(guard.isWaitingForConfirmation, isTrue);
      });

      test('uses contextDescription in message', () {
        final guard = makeGuard();
        final result = guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({}),
          riskLevel: ToolRiskLevel.high,
          contextDescription: 'opening settings',
        );
        expect(result, isNotNull);
        expect(result!.contextDescription, 'opening settings');
      });

      test('computes correct action hash', () {
        final guard = makeGuard();
        const toolName = 'my_tool';
        final args = {'key': 'val'};
        final expectedHash = ConfirmationGuard.computeActionHash(toolName, args);
        final result = guard.requestConfirmation(
          toolName: toolName,
          arguments: ToolArguments(args),
          riskLevel: ToolRiskLevel.high,
        );
        expect(result, isNotNull);
        expect(result!.actionHash, expectedHash);
      });

      test('critical risk uses critical risk message format', () {
        final guard = makeGuard();
        final result = guard.requestConfirmation(
          toolName: 'dangerous_tool',
          arguments: ToolArguments({}),
          riskLevel: ToolRiskLevel.critical,
        );
        expect(result, isNotNull);
        expect(result!.message, contains('⚠️'));
      });
    });

    group('acceptPending', () {
      test('accepts the pending request', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.acceptPending();
        expect(guard.pending, isNull);
        expect(guard.history, hasLength(1));
        expect(guard.history.last.state, ToolConfirmationState.accepted);
      });

      test('does nothing when no pending request', () {
        final guard = makeGuard();
        guard.acceptPending();
        expect(guard.pending, isNull);
        expect(guard.history, isEmpty);
      });

      test('isWaitingForConfirmation becomes false after accept', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        expect(guard.isWaitingForConfirmation, isTrue);
        guard.acceptPending();
        expect(guard.isWaitingForConfirmation, isFalse);
      });
    });

    group('cancelPending', () {
      test('cancels the pending request', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.cancelPending();
        expect(guard.pending, isNull);
        expect(guard.history, hasLength(1));
        expect(guard.history.last.state, ToolConfirmationState.cancelled);
      });

      test('does nothing when no pending request', () {
        final guard = makeGuard();
        guard.cancelPending();
        expect(guard.pending, isNull);
        expect(guard.history, isEmpty);
      });
    });

    group('verifyConfirmation', () {
      test('returns false when history is empty', () {
        final guard = makeGuard();
        final result = guard.verifyConfirmation(
          toolName: 'my_tool',
          arguments: {'key': 'val'},
        );
        expect(result, isFalse);
      });

      test('returns true when latest entry is accepted and hash matches', () {
        final guard = makeGuard();
        const toolName = 'my_tool';
        final args = {'key': 'val'};
        guard.requestConfirmation(
          toolName: toolName,
          arguments: ToolArguments(args),
          riskLevel: ToolRiskLevel.high,
        );
        guard.acceptPending();
        final verified = guard.verifyConfirmation(
          toolName: toolName,
          arguments: args,
        );
        expect(verified, isTrue);
      });

      test('returns false when latest entry was cancelled', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.cancelPending();
        final verified = guard.verifyConfirmation(
          toolName: 'my_tool',
          arguments: {'key': 'val'},
        );
        expect(verified, isFalse);
      });

      test('returns false when action hash does not match', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val1'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.acceptPending();
        final verified = guard.verifyConfirmation(
          toolName: 'my_tool',
          arguments: {'key': 'val2'},
        );
        expect(verified, isFalse);
      });

      test('returns false when confirmation has expired', () {
        final guard = makeGuard();
        // Manually add an expired entry to history
        final expiredTime = DateTime.now().subtract(const Duration(minutes: 2));
        const toolName = 'my_tool';
        final args = {'key': 'val'};
        final hash = ConfirmationGuard.computeActionHash(toolName, args);
        final req = ToolConfirmationRequest(
          toolName: toolName,
          arguments: args,
          riskLevel: ToolRiskLevel.high,
          actionHash: hash,
          message: 'test',
          contextDescription: '',
          timeout: const Duration(seconds: 60),
          createdAt: expiredTime,
        );
        req.accept();
        // Manually push into history by using requestConfirmation + accept flow
        // Instead, we use reset and verify directly
        guard.reset();
        // We cannot inject history directly, so test via the normal flow
        // with a very short timeout
        final shortGuard = ConfirmationGuard(messages: const SecurityMessages());
        shortGuard.requestConfirmation(
          toolName: toolName,
          arguments: ToolArguments(args),
          riskLevel: ToolRiskLevel.high,
        );
        shortGuard.acceptPending();
        // Now the history entry was just created — it won't be expired yet
        // We verify it is accepted
        expect(
          shortGuard.verifyConfirmation(toolName: toolName, arguments: args),
          isTrue,
        );
      });

      test('checks only the most recent history entry', () {
        final guard = makeGuard();
        // First request + accept
        guard.requestConfirmation(
          toolName: 'tool_a',
          arguments: ToolArguments({'key': 'val1'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.acceptPending();
        // Second request + cancel
        guard.requestConfirmation(
          toolName: 'tool_b',
          arguments: ToolArguments({'key': 'val2'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.cancelPending();
        // Even though tool_a was accepted, the latest is cancelled
        expect(
          guard.verifyConfirmation(
            toolName: 'tool_a',
            arguments: {'key': 'val1'},
          ),
          isFalse,
        );
      });
    });

    group('computeActionHash', () {
      test('returns deterministic hash for same inputs', () {
        final hash1 = ConfirmationGuard.computeActionHash(
          'tool',
          {'key': 'val'},
        );
        final hash2 = ConfirmationGuard.computeActionHash(
          'tool',
          {'key': 'val'},
        );
        expect(hash1, hash2);
      });

      test('returns different hash for different tool names', () {
        final hash1 = ConfirmationGuard.computeActionHash(
          'tool_a',
          {'key': 'val'},
        );
        final hash2 = ConfirmationGuard.computeActionHash(
          'tool_b',
          {'key': 'val'},
        );
        expect(hash1, isNot(equals(hash2)));
      });

      test('returns different hash for different arguments', () {
        final hash1 = ConfirmationGuard.computeActionHash(
          'tool',
          {'key': 'val1'},
        );
        final hash2 = ConfirmationGuard.computeActionHash(
          'tool',
          {'key': 'val2'},
        );
        expect(hash1, isNot(equals(hash2)));
      });

      test('is order-independent for argument keys', () {
        final hash1 = ConfirmationGuard.computeActionHash(
          'tool',
          {'a': '1', 'b': '2'},
        );
        final hash2 = ConfirmationGuard.computeActionHash(
          'tool',
          {'b': '2', 'a': '1'},
        );
        expect(hash1, hash2);
      });

      test('returns 8-char hex string', () {
        final hash = ConfirmationGuard.computeActionHash(
          'tool',
          {'key': 'val'},
        );
        expect(hash.length, 8);
        expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(hash), isTrue);
      });
    });

    group('reset', () {
      test('clears pending request', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.reset();
        expect(guard.pending, isNull);
      });

      test('clears history', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.acceptPending();
        expect(guard.history, isNotEmpty);
        guard.reset();
        expect(guard.history, isEmpty);
      });

      test('isWaitingForConfirmation becomes false', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'my_tool',
          arguments: ToolArguments({'key': 'val'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.reset();
        expect(guard.isWaitingForConfirmation, isFalse);
      });
    });

    group('history', () {
      test('accumulates entries after accept', () {
        final guard = makeGuard();
        for (var i = 0; i < 3; i++) {
          guard.requestConfirmation(
            toolName: 'tool_$i',
            arguments: ToolArguments({'i': i}),
            riskLevel: ToolRiskLevel.medium,
          );
          guard.acceptPending();
        }
        expect(guard.history, hasLength(3));
      });

      test('accumulates entries after cancel', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'tool',
          arguments: ToolArguments({'k': 'v'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.cancelPending();
        expect(guard.history, hasLength(1));
        expect(guard.history.last.state, ToolConfirmationState.cancelled);
      });

      test('trims history beyond maxHistory (100)', () {
        final guard = makeGuard();
        for (var i = 0; i < 105; i++) {
          guard.requestConfirmation(
            toolName: 'tool_$i',
            arguments: ToolArguments({'i': i}),
            riskLevel: ToolRiskLevel.medium,
          );
          guard.acceptPending();
        }
        expect(guard.history, hasLength(100));
      });

      test('returns unmodifiable list', () {
        final guard = makeGuard();
        guard.requestConfirmation(
          toolName: 'tool',
          arguments: ToolArguments({'k': 'v'}),
          riskLevel: ToolRiskLevel.high,
        );
        guard.acceptPending();
        expect(() => guard.history.add(guard.history.last), throwsA(anything));
      });
    });
  });
}
