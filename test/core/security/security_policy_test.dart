import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:aura_assistant/core/security/security_policy.dart';
import 'package:aura_assistant/core/tools/tool_permission.dart';
import 'package:aura_assistant/core/agent/agent_confirmation_manager.dart';

void main() {
  group('SecurityPolicy', () {
    group('default constructor', () {
      test('uses built-in permission map', () {
        final policy = SecurityPolicy();
        expect(policy.resolvePermission(ToolPermission.microphone),
            ph.Permission.microphone);
        expect(policy.resolvePermission(ToolPermission.camera),
            ph.Permission.camera);
      });

      test('maps none to null', () {
        final policy = SecurityPolicy();
        expect(policy.resolvePermission(ToolPermission.none), isNull);
      });

      test('maps network to null', () {
        final policy = SecurityPolicy();
        expect(policy.resolvePermission(ToolPermission.network), isNull);
      });

      test('maps battery to null', () {
        final policy = SecurityPolicy();
        expect(policy.resolvePermission(ToolPermission.battery), isNull);
      });

      test('uses built-in sensitive settings', () {
        final policy = SecurityPolicy();
        expect(policy.sensitiveSettings.containsKey('security'), isTrue);
        expect(policy.sensitiveSettings['security'], ToolRiskLevel.critical);
      });

      test('uses built-in sensitive protocols', () {
        final policy = SecurityPolicy();
        expect(policy.sensitiveProtocols, contains('tel'));
        expect(policy.sensitiveProtocols, contains('sms'));
        expect(policy.sensitiveProtocols, contains('mailto'));
        expect(policy.sensitiveProtocols, contains('market'));
      });

      test('uses built-in sensitive packages', () {
        final policy = SecurityPolicy();
        expect(policy.sensitivePackages, contains('com.android.settings'));
      });
    });

    group('custom constructor', () {
      test('accepts custom permission map', () {
        final customMap = <ToolPermission, ph.Permission?>{
          ToolPermission.microphone: null,
        };
        final policy = SecurityPolicy(permissionMap: customMap);
        expect(policy.resolvePermission(ToolPermission.microphone), isNull);
      });

      test('accepts custom sensitive settings', () {
        final customSettings = <String, ToolRiskLevel>{
          'custom_key': ToolRiskLevel.high,
        };
        final policy = SecurityPolicy(sensitiveSettings: customSettings);
        expect(policy.sensitiveSettings, hasLength(1));
        expect(policy.sensitiveSettings['custom_key'], ToolRiskLevel.high);
      });

      test('accepts custom sensitive protocols', () {
        final customProtocols = <String>{'ftp'};
        final policy = SecurityPolicy(sensitiveProtocols: customProtocols);
        expect(policy.sensitiveProtocols, hasLength(1));
        expect(policy.sensitiveProtocols, contains('ftp'));
      });

      test('accepts custom sensitive packages', () {
        final customPackages = <String>{'com.example.sensitive'};
        final policy = SecurityPolicy(sensitivePackages: customPackages);
        expect(policy.sensitivePackages, hasLength(1));
        expect(policy.sensitivePackages, contains('com.example.sensitive'));
      });
    });

    group('resolvePermission', () {
      test('returns correct permission for known mappings', () {
        final policy = SecurityPolicy();
        expect(policy.resolvePermission(ToolPermission.microphone),
            ph.Permission.microphone);
        expect(policy.resolvePermission(ToolPermission.camera),
            ph.Permission.camera);
        expect(policy.resolvePermission(ToolPermission.storage),
            ph.Permission.storage);
        expect(policy.resolvePermission(ToolPermission.location),
            ph.Permission.location);
        expect(policy.resolvePermission(ToolPermission.notifications),
            ph.Permission.notification);
        expect(policy.resolvePermission(ToolPermission.contacts),
            ph.Permission.contacts);
        expect(policy.resolvePermission(ToolPermission.phone),
            ph.Permission.phone);
        expect(policy.resolvePermission(ToolPermission.system),
            ph.Permission.accessNotificationPolicy);
      });

      test('returns null for none/network/battery', () {
        final policy = SecurityPolicy();
        expect(policy.resolvePermission(ToolPermission.none), isNull);
        expect(policy.resolvePermission(ToolPermission.network), isNull);
        expect(policy.resolvePermission(ToolPermission.battery), isNull);
      });
    });

    group('resolvePermissions', () {
      test('returns empty list for no requirements', () {
        final policy = SecurityPolicy();
        final result = policy.resolvePermissions([]);
        expect(result, isEmpty);
      });

      test('returns non-null permissions for required entries', () {
        final policy = SecurityPolicy();
        final requirements = [
          ToolPermissionRequirement(
            permission: ToolPermission.microphone,
            isRequired: true,
          ),
        ];
        final result = policy.resolvePermissions(requirements);
        expect(result, hasLength(1));
        expect(result.first, ph.Permission.microphone);
      });

      test('skips optional requirements', () {
        final policy = SecurityPolicy();
        final requirements = [
          ToolPermissionRequirement(
            permission: ToolPermission.microphone,
            isRequired: false,
          ),
        ];
        final result = policy.resolvePermissions(requirements);
        expect(result, isEmpty);
      });

      test('skips null-mapped permissions', () {
        final policy = SecurityPolicy();
        final requirements = [
          ToolPermissionRequirement(
            permission: ToolPermission.network,
            isRequired: true,
          ),
        ];
        final result = policy.resolvePermissions(requirements);
        expect(result, isEmpty);
      });

      test('resolves multiple requirements', () {
        final policy = SecurityPolicy();
        final requirements = [
          ToolPermissionRequirement(
            permission: ToolPermission.microphone,
            isRequired: true,
          ),
          ToolPermissionRequirement(
            permission: ToolPermission.camera,
            isRequired: true,
          ),
        ];
        final result = policy.resolvePermissions(requirements);
        expect(result, hasLength(2));
      });
    });

    group('isValidPackageName', () {
      test('accepts valid package names', () {
        final policy = SecurityPolicy();
        expect(policy.isValidPackageName('com.example.app'), isTrue);
        expect(policy.isValidPackageName('com.example'), isTrue);
        expect(policy.isValidPackageName('a.b'), isTrue);
        expect(policy.isValidPackageName('com.test.myapp123'), isTrue);
        expect(policy.isValidPackageName('org.foundation.tool'), isTrue);
      });

      test('rejects package names starting with digit', () {
        final policy = SecurityPolicy();
        expect(policy.isValidPackageName('1bad.name'), isFalse);
      });

      test('rejects package names with uppercase letters', () {
        final policy = SecurityPolicy();
        expect(policy.isValidPackageName('Com.example.app'), isFalse);
        expect(policy.isValidPackageName('com.Example.app'), isFalse);
      });

      test('rejects package names without dots', () {
        final policy = SecurityPolicy();
        expect(policy.isValidPackageName('nodot'), isFalse);
      });

      test('rejects empty string', () {
        final policy = SecurityPolicy();
        expect(policy.isValidPackageName(''), isFalse);
      });

      test('rejects package names with underscores', () {
        final policy = SecurityPolicy();
        expect(policy.isValidPackageName('com.example_app.test'), isFalse);
      });

      test('rejects package names starting segment with digit', () {
        final policy = SecurityPolicy();
        expect(policy.isValidPackageName('com.2bad.test'), isFalse);
      });
    });

    group('isValidSettingsKey', () {
      test('accepts valid settings keys', () {
        final policy = SecurityPolicy();
        expect(policy.isValidSettingsKey('wifi'), isTrue);
        expect(policy.isValidSettingsKey('security'), isTrue);
        expect(policy.isValidSettingsKey('location_mode'), isTrue);
        expect(policy.isValidSettingsKey('abc123'), isTrue);
        expect(policy.isValidSettingsKey('a'), isTrue);
      });

      test('rejects settings keys starting with digit', () {
        final policy = SecurityPolicy();
        expect(policy.isValidSettingsKey('1bad'), isFalse);
      });

      test('rejects settings keys with dashes', () {
        final policy = SecurityPolicy();
        expect(policy.isValidSettingsKey('has-dash'), isFalse);
      });

      test('rejects empty string', () {
        final policy = SecurityPolicy();
        expect(policy.isValidSettingsKey(''), isFalse);
      });

      test('rejects settings keys with uppercase', () {
        final policy = SecurityPolicy();
        expect(policy.isValidSettingsKey('BadKey'), isFalse);
      });

      test('rejects settings keys with dots', () {
        final policy = SecurityPolicy();
        expect(policy.isValidSettingsKey('a.b'), isFalse);
      });
    });

    group('isAllowedUrlProtocol', () {
      test('allows http and https', () {
        final policy = SecurityPolicy();
        expect(policy.isAllowedUrlProtocol('https://example.com'), isTrue);
        expect(policy.isAllowedUrlProtocol('http://example.com'), isTrue);
      });

      test('allows sensitive but allowed protocols', () {
        final policy = SecurityPolicy();
        expect(policy.isAllowedUrlProtocol('tel:+1234567890'), isTrue);
        expect(policy.isAllowedUrlProtocol('sms:+1234567890'), isTrue);
        expect(policy.isAllowedUrlProtocol('mailto:test@example.com'), isTrue);
        expect(policy.isAllowedUrlProtocol('market://details?id=com.app'),
            isTrue);
      });

      test('rejects disallowed protocols', () {
        final policy = SecurityPolicy();
        expect(policy.isAllowedUrlProtocol('ftp://example.com'), isFalse);
        expect(policy.isAllowedUrlProtocol('javascript:alert(1)'), isFalse);
      });

      test('rejects malformed URLs', () {
        final policy = SecurityPolicy();
        expect(policy.isAllowedUrlProtocol('not a url at all'), isFalse);
      });
    });

    group('isSensitiveUrlProtocol', () {
      test('detects tel as sensitive', () {
        final policy = SecurityPolicy();
        expect(policy.isSensitiveUrlProtocol('tel:+1234567890'), isTrue);
      });

      test('detects sms as sensitive', () {
        final policy = SecurityPolicy();
        expect(policy.isSensitiveUrlProtocol('sms:+1234567890'), isTrue);
      });

      test('detects mailto as sensitive', () {
        final policy = SecurityPolicy();
        expect(
            policy.isSensitiveUrlProtocol('mailto:test@example.com'), isTrue);
      });

      test('detects market as sensitive', () {
        final policy = SecurityPolicy();
        expect(
            policy.isSensitiveUrlProtocol('market://details?id=com.app'), isTrue);
      });

      test('https is not sensitive', () {
        final policy = SecurityPolicy();
        expect(policy.isSensitiveUrlProtocol('https://example.com'), isFalse);
      });

      test('http is not sensitive', () {
        final policy = SecurityPolicy();
        expect(policy.isAllowedUrlProtocol('http://example.com'), isTrue);
        expect(policy.isSensitiveUrlProtocol('http://example.com'), isFalse);
      });

      test('malformed URL returns false', () {
        final policy = SecurityPolicy();
        expect(policy.isSensitiveUrlProtocol('not a url'), isFalse);
      });
    });

    group('isSensitivePackage', () {
      test('detects sensitive package by prefix', () {
        final policy = SecurityPolicy();
        expect(
            policy.isSensitivePackage('com.android.settings'), isTrue);
        expect(
            policy.isSensitivePackage('com.android.settings.sub'), isTrue);
      });

      test('detects com.android.security as sensitive', () {
        final policy = SecurityPolicy();
        expect(
            policy.isSensitivePackage('com.android.security'), isTrue);
      });

      test('non-sensitive package returns false', () {
        final policy = SecurityPolicy();
        expect(
            policy.isSensitivePackage('com.example.myapp'), isFalse);
      });

      test('custom sensitive packages', () {
        final policy = SecurityPolicy(
          sensitivePackages: {'com.custom.sensitive'},
        );
        expect(policy.isSensitivePackage('com.custom.sensitive'), isTrue);
        expect(
            policy.isSensitivePackage('com.custom.sensitive.sub'), isTrue);
        expect(
            policy.isSensitivePackage('com.custom.other'), isFalse);
      });
    });

    group('elevatedRiskForSettingsKey', () {
      test('elevates risk for security key', () {
        final policy = SecurityPolicy();
        final result = policy.elevatedRiskForSettingsKey(
          'security',
          ToolRiskLevel.low,
        );
        expect(result, ToolRiskLevel.critical);
      });

      test('elevates risk for accessibility key', () {
        final policy = SecurityPolicy();
        final result = policy.elevatedRiskForSettingsKey(
          'accessibility',
          ToolRiskLevel.low,
        );
        expect(result, ToolRiskLevel.critical);
      });

      test('elevates risk for location key', () {
        final policy = SecurityPolicy();
        final result = policy.elevatedRiskForSettingsKey(
          'location',
          ToolRiskLevel.low,
        );
        expect(result, ToolRiskLevel.high);
      });

      test('returns default risk for non-sensitive key', () {
        final policy = SecurityPolicy();
        final result = policy.elevatedRiskForSettingsKey(
          'wifi',
          ToolRiskLevel.low,
        );
        expect(result, ToolRiskLevel.low);
      });

      test('is case-insensitive', () {
        final policy = SecurityPolicy();
        final result = policy.elevatedRiskForSettingsKey(
          'Security',
          ToolRiskLevel.low,
        );
        expect(result, ToolRiskLevel.critical);
      });

      test('custom sensitive settings', () {
        final policy = SecurityPolicy(
          sensitiveSettings: {'my_key': ToolRiskLevel.high},
        );
        final result = policy.elevatedRiskForSettingsKey(
          'my_key',
          ToolRiskLevel.none,
        );
        expect(result, ToolRiskLevel.high);
      });
    });

    group('checkSecurityBoundaries', () {
      test('returns empty when no boundaries are violated', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries();
        expect(violations, isEmpty);
      });

      test('returns empty when all boundaries are false', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsShellExec: false,
          attemptsArbitraryPackage: false,
          attemptsIntentAbuse: false,
          attemptsPermissionBypass: false,
          attemptsAccessibilityAbuse: false,
          attemptsHiddenBackgroundAction: false,
          attemptsSecurityBypass: false,
          attemptsSilentSensitiveAction: false,
        );
        expect(violations, isEmpty);
      });

      test('detects shellExec violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsShellExec: true,
        );
        expect(violations, hasLength(1));
        expect(violations.first, SecurityBoundaryViolation.shellExec);
      });

      test('detects arbitraryPackage violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsArbitraryPackage: true,
        );
        expect(violations, hasLength(1));
        expect(violations.first, SecurityBoundaryViolation.arbitraryPackage);
      });

      test('detects intentAbuse violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsIntentAbuse: true,
        );
        expect(violations, hasLength(1));
        expect(violations.first, SecurityBoundaryViolation.intentAbuse);
      });

      test('detects permissionBypass violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsPermissionBypass: true,
        );
        expect(violations, hasLength(1));
        expect(violations.first, SecurityBoundaryViolation.permissionBypass);
      });

      test('detects accessibilityAbuse violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsAccessibilityAbuse: true,
        );
        expect(violations, hasLength(1));
        expect(violations.first, SecurityBoundaryViolation.accessibilityAbuse);
      });

      test('detects hiddenBackgroundAction violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsHiddenBackgroundAction: true,
        );
        expect(violations, hasLength(1));
        expect(
            violations.first, SecurityBoundaryViolation.hiddenBackgroundAction);
      });

      test('detects securityBypass violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsSecurityBypass: true,
        );
        expect(violations, hasLength(1));
        expect(violations.first, SecurityBoundaryViolation.securityBypass);
      });

      test('detects silentSensitiveAction violation', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsSilentSensitiveAction: true,
        );
        expect(violations, hasLength(1));
        expect(
            violations.first, SecurityBoundaryViolation.silentSensitiveAction);
      });

      test('detects multiple violations at once', () {
        final policy = SecurityPolicy();
        final violations = policy.checkSecurityBoundaries(
          attemptsShellExec: true,
          attemptsIntentAbuse: true,
          attemptsSecurityBypass: true,
        );
        expect(violations, hasLength(3));
        expect(violations, contains(SecurityBoundaryViolation.shellExec));
        expect(violations, contains(SecurityBoundaryViolation.intentAbuse));
        expect(violations, contains(SecurityBoundaryViolation.securityBypass));
      });
    });
  });

  group('SecurityBoundaryViolation', () {
    test('shellExec has bilingual message', () {
      final msg = SecurityBoundaryViolation.shellExec.message;
      expect(msg, contains('Shell execution is not allowed'));
      expect(msg, contains('شێڵ'));
    });

    test('arbitraryPackage has bilingual message', () {
      final msg = SecurityBoundaryViolation.arbitraryPackage.message;
      expect(msg, contains('Arbitrary package installation'));
      expect(msg, contains('پاکێج'));
    });

    test('intentAbuse has bilingual message', () {
      final msg = SecurityBoundaryViolation.intentAbuse.message;
      expect(msg, contains('Intent abuse'));
      expect(msg, contains('intent'));
    });

    test('permissionBypass has bilingual message', () {
      final msg = SecurityBoundaryViolation.permissionBypass.message;
      expect(msg, contains('Permission bypass'));
      expect(msg, contains('ڕێگەپێدان'));
    });

    test('accessibilityAbuse has bilingual message', () {
      final msg = SecurityBoundaryViolation.accessibilityAbuse.message;
      expect(msg, contains('Accessibility abuse'));
      expect(msg, contains('دەستگەیشتن'));
    });

    test('hiddenBackgroundAction has bilingual message', () {
      final msg = SecurityBoundaryViolation.hiddenBackgroundAction.message;
      expect(msg, contains('Hidden background actions'));
      expect(msg, contains('پشتەوە'));
    });

    test('securityBypass has bilingual message', () {
      final msg = SecurityBoundaryViolation.securityBypass.message;
      expect(msg, contains('Security bypass'));
      expect(msg, contains('ئاسایش'));
    });

    test('silentSensitiveAction has bilingual message', () {
      final msg = SecurityBoundaryViolation.silentSensitiveAction.message;
      expect(msg, contains('Sensitive actions require confirmation'));
      expect(msg, contains('هەستیار'));
    });

    test('all 8 enum values exist', () {
      expect(SecurityBoundaryViolation.values, hasLength(8));
    });
  });
}
