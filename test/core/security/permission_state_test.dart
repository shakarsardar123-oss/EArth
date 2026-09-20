import 'package:flutter_test/flutter_test.dart';
import 'package:aura_assistant/core/security/permission_state.dart';
import 'package:aura_assistant/core/tools/tool_permission.dart';

void main() {
  group('ToolPermissionStatus', () {
    group('granted', () {
      test('isAllowed returns true', () {
        expect(ToolPermissionStatus.granted.isAllowed, isTrue);
      });

      test('canRequest returns false', () {
        expect(ToolPermissionStatus.granted.canRequest, isFalse);
      });

      test('shouldFallback returns false', () {
        expect(ToolPermissionStatus.granted.shouldFallback, isFalse);
      });
    });

    group('denied', () {
      test('isAllowed returns false', () {
        expect(ToolPermissionStatus.denied.isAllowed, isFalse);
      });

      test('canRequest returns true', () {
        expect(ToolPermissionStatus.denied.canRequest, isTrue);
      });

      test('shouldFallback returns false', () {
        expect(ToolPermissionStatus.denied.shouldFallback, isFalse);
      });
    });

    group('permanentlyDenied', () {
      test('isAllowed returns false', () {
        expect(ToolPermissionStatus.permanentlyDenied.isAllowed, isFalse);
      });

      test('canRequest returns false', () {
        expect(ToolPermissionStatus.permanentlyDenied.canRequest, isFalse);
      });

      test('shouldFallback returns true', () {
        expect(ToolPermissionStatus.permanentlyDenied.shouldFallback, isTrue);
      });
    });

    group('unsupported', () {
      test('isAllowed returns false', () {
        expect(ToolPermissionStatus.unsupported.isAllowed, isFalse);
      });

      test('canRequest returns false', () {
        expect(ToolPermissionStatus.unsupported.canRequest, isFalse);
      });

      test('shouldFallback returns true', () {
        expect(ToolPermissionStatus.unsupported.shouldFallback, isTrue);
      });
    });
  });

  group('PermissionCheckResult', () {
    group('isAllGranted', () {
      test('returns true when overallStatus is granted', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.granted,
          permissionStatuses: {},
        );
        expect(result.isAllGranted, isTrue);
      });

      test('returns false when overallStatus is denied', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.denied,
          permissionStatuses: {},
          deniedPermissions: ['microphone'],
        );
        expect(result.isAllGranted, isFalse);
      });

      test('returns false when overallStatus is permanentlyDenied', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.permanentlyDenied,
          permissionStatuses: {},
          permanentlyDeniedPermissions: ['camera'],
        );
        expect(result.isAllGranted, isFalse);
      });

      test('returns false when overallStatus is unsupported', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.unsupported,
          permissionStatuses: {},
          unsupportedPermissions: ['location'],
        );
        expect(result.isAllGranted, isFalse);
      });
    });

    group('needsGracefulFallback', () {
      test('returns true when permanentlyDeniedPermissions is non-empty', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.permanentlyDenied,
          permissionStatuses: {},
          permanentlyDeniedPermissions: ['camera'],
        );
        expect(result.needsGracefulFallback, isTrue);
      });

      test('returns true when unsupportedPermissions is non-empty', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.unsupported,
          permissionStatuses: {},
          unsupportedPermissions: ['location'],
        );
        expect(result.needsGracefulFallback, isTrue);
      });

      test('returns true when both permanent and unsupported exist', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.permanentlyDenied,
          permissionStatuses: {},
          permanentlyDeniedPermissions: ['camera'],
          unsupportedPermissions: ['location'],
        );
        expect(result.needsGracefulFallback, isTrue);
      });

      test('returns false when only denied (not permanent/unsupported)', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.denied,
          permissionStatuses: {},
          deniedPermissions: ['microphone'],
        );
        expect(result.needsGracefulFallback, isFalse);
      });

      test('returns false when all granted', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.granted,
          permissionStatuses: {},
        );
        expect(result.needsGracefulFallback, isFalse);
      });

      test('returns false when empty result', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.granted,
          permissionStatuses: {},
        );
        expect(result.needsGracefulFallback, isFalse);
      });
    });

    group('canRequestAny', () {
      test('returns true when deniedPermissions is non-empty', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.denied,
          permissionStatuses: {},
          deniedPermissions: ['microphone'],
        );
        expect(result.canRequestAny, isTrue);
      });

      test('returns false when only permanentlyDenied', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.permanentlyDenied,
          permissionStatuses: {},
          permanentlyDeniedPermissions: ['camera'],
        );
        expect(result.canRequestAny, isFalse);
      });

      test('returns false when only unsupported', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.unsupported,
          permissionStatuses: {},
          unsupportedPermissions: ['location'],
        );
        expect(result.canRequestAny, isFalse);
      });

      test('returns false when all granted', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.granted,
          permissionStatuses: {},
        );
        expect(result.canRequestAny, isFalse);
      });

      test('returns true when both denied and permanent exist', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.denied,
          permissionStatuses: {},
          deniedPermissions: ['microphone'],
          permanentlyDeniedPermissions: ['camera'],
        );
        expect(result.canRequestAny, isTrue);
      });
    });

    group('toString', () {
      test('contains overallStatus', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.denied,
          permissionStatuses: {},
          deniedPermissions: ['mic'],
          permanentlyDeniedPermissions: ['cam'],
          unsupportedPermissions: ['loc'],
        );
        final str = result.toString();
        expect(str, contains('denied'));
        expect(str, contains('mic'));
        expect(str, contains('cam'));
        expect(str, contains('loc'));
      });
    });

    group('permissionStatuses', () {
      test('maps status to list of permission names', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.denied,
          permissionStatuses: {
            ToolPermissionStatus.granted: ['storage'],
            ToolPermissionStatus.denied: ['microphone'],
          },
          deniedPermissions: ['microphone'],
        );
        expect(result.permissionStatuses[ToolPermissionStatus.granted],
            ['storage']);
        expect(result.permissionStatuses[ToolPermissionStatus.denied],
            ['microphone']);
      });
    });

    group('messages', () {
      test('can carry bilingual messages', () {
        const result = PermissionCheckResult(
          overallStatus: ToolPermissionStatus.denied,
          permissionStatuses: {},
          messages: ['ڕێگەپێدان ڕەتکرایەوە / Permission denied'],
        );
        expect(result.messages, hasLength(1));
        expect(result.messages.first, contains('Permission denied'));
      });
    });
  });
}
