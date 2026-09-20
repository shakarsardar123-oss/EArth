import 'package:flutter_test/flutter_test.dart';

import 'package:aura_assistant/core/floating_aura/floating_aura_constants.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_overlay_position.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_state.dart';

void main() {
  // ── FloatingAuraOverlayStatus ──────────────────────────────

  group('FloatingAuraOverlayStatus', () {
    group('isOverlayVisible', () {
      test('idle returns false', () {
        expect(FloatingAuraOverlayStatus.idle.isOverlayVisible, isFalse);
      });

      test('requestingPermission returns false', () {
        expect(
            FloatingAuraOverlayStatus.requestingPermission.isOverlayVisible,
            isFalse);
      });

      test('showing returns true', () {
        expect(
            FloatingAuraOverlayStatus.showing.isOverlayVisible, isTrue);
      });

      test('hiding returns false', () {
        expect(FloatingAuraOverlayStatus.hiding.isOverlayVisible, isFalse);
      });

      test('error returns false', () {
        expect(FloatingAuraOverlayStatus.error.isOverlayVisible, isFalse);
      });
    });

    group('canShow', () {
      test('idle returns true', () {
        expect(FloatingAuraOverlayStatus.idle.canShow, isTrue);
      });

      test('requestingPermission returns false', () {
        expect(
            FloatingAuraOverlayStatus.requestingPermission.canShow, isFalse);
      });

      test('showing returns false', () {
        expect(FloatingAuraOverlayStatus.showing.canShow, isFalse);
      });

      test('hiding returns false', () {
        expect(FloatingAuraOverlayStatus.hiding.canShow, isFalse);
      });

      test('error returns true', () {
        expect(FloatingAuraOverlayStatus.error.canShow, isTrue);
      });
    });

    group('canHide', () {
      test('idle returns false', () {
        expect(FloatingAuraOverlayStatus.idle.canHide, isFalse);
      });

      test('requestingPermission returns false', () {
        expect(
            FloatingAuraOverlayStatus.requestingPermission.canHide, isFalse);
      });

      test('showing returns true', () {
        expect(FloatingAuraOverlayStatus.showing.canHide, isTrue);
      });

      test('hiding returns false', () {
        expect(FloatingAuraOverlayStatus.hiding.canHide, isFalse);
      });

      test('error returns false', () {
        expect(FloatingAuraOverlayStatus.error.canHide, isFalse);
      });
    });

    group('canTogglePanel', () {
      test('idle returns false', () {
        expect(FloatingAuraOverlayStatus.idle.canTogglePanel, isFalse);
      });

      test('requestingPermission returns false', () {
        expect(FloatingAuraOverlayStatus.requestingPermission.canTogglePanel,
            isFalse);
      });

      test('showing returns true', () {
        expect(FloatingAuraOverlayStatus.showing.canTogglePanel, isTrue);
      });

      test('hiding returns false', () {
        expect(FloatingAuraOverlayStatus.hiding.canTogglePanel, isFalse);
      });

      test('error returns false', () {
        expect(FloatingAuraOverlayStatus.error.canTogglePanel, isFalse);
      });
    });
  });

  // ── FloatingAuraState ───────────────────────────────────────

  group('FloatingAuraState', () {
    test('default constructor values', () {
      const state = FloatingAuraState();
      expect(state.status, FloatingAuraOverlayStatus.idle);
      expect(state.lastError, isNull);
      expect(state.hasPermission, isFalse);
      expect(state.isExpanded, isFalse);
      expect(state.position, isNull);
    });

    test('custom constructor values', () {
      const position = FloatingAuraOverlayPosition(x: 50.0, y: 200.0);
      const state = FloatingAuraState(
        status: FloatingAuraOverlayStatus.showing,
        lastError: 'some error',
        hasPermission: true,
        isExpanded: true,
        position: position,
      );
      expect(state.status, FloatingAuraOverlayStatus.showing);
      expect(state.lastError, 'some error');
      expect(state.hasPermission, isTrue);
      expect(state.isExpanded, isTrue);
      expect(state.position, position);
    });

    group('delegated getters', () {
      test('isOverlayVisible delegates to status', () {
        const idle = FloatingAuraState(
            status: FloatingAuraOverlayStatus.idle);
        const showing = FloatingAuraState(
            status: FloatingAuraOverlayStatus.showing);
        expect(idle.isOverlayVisible, isFalse);
        expect(showing.isOverlayVisible, isTrue);
      });

      test('canShow delegates to status', () {
        const idle = FloatingAuraState(
            status: FloatingAuraOverlayStatus.idle);
        const showing = FloatingAuraState(
            status: FloatingAuraOverlayStatus.showing);
        const error = FloatingAuraState(
            status: FloatingAuraOverlayStatus.error);
        expect(idle.canShow, isTrue);
        expect(showing.canShow, isFalse);
        expect(error.canShow, isTrue);
      });

      test('canHide delegates to status', () {
        const idle = FloatingAuraState(
            status: FloatingAuraOverlayStatus.idle);
        const showing = FloatingAuraState(
            status: FloatingAuraOverlayStatus.showing);
        expect(idle.canHide, isFalse);
        expect(showing.canHide, isTrue);
      });

      test('canTogglePanel delegates to status', () {
        const idle = FloatingAuraState(
            status: FloatingAuraOverlayStatus.idle);
        const showing = FloatingAuraState(
            status: FloatingAuraOverlayStatus.showing);
        expect(idle.canTogglePanel, isFalse);
        expect(showing.canTogglePanel, isTrue);
      });
    });

    group('resolvedPosition', () {
      test('returns defaults when position is null', () {
        const state = FloatingAuraState();
        expect(state.resolvedPosition, FloatingAuraOverlayPosition.defaults);
      });

      test('returns the actual position when set', () {
        const position = FloatingAuraOverlayPosition(x: 50.0, y: 200.0);
        const state = FloatingAuraState(position: position);
        expect(state.resolvedPosition, position);
      });
    });

    group('copyWith', () {
      test('copies all fields', () {
        const original = FloatingAuraState();
        const position = FloatingAuraOverlayPosition(x: 10.0, y: 20.0);
        final copied = original.copyWith(
          status: FloatingAuraOverlayStatus.showing,
          lastError: 'err',
          hasPermission: true,
          isExpanded: true,
          position: position,
        );
        expect(copied.status, FloatingAuraOverlayStatus.showing);
        expect(copied.lastError, 'err');
        expect(copied.hasPermission, isTrue);
        expect(copied.isExpanded, isTrue);
        expect(copied.position, position);
      });

      test('preserves existing fields when no arguments given', () {
        const position = FloatingAuraOverlayPosition(x: 10.0, y: 20.0);
        const state = FloatingAuraState(
          status: FloatingAuraOverlayStatus.showing,
          lastError: 'err',
          hasPermission: true,
          isExpanded: true,
          position: position,
        );
        final copied = state.copyWith();
        expect(copied.status, FloatingAuraOverlayStatus.showing);
        expect(copied.lastError, 'err');
        expect(copied.hasPermission, isTrue);
        expect(copied.isExpanded, isTrue);
        expect(copied.position, position);
      });

      test('clearError clears lastError', () {
        const state = FloatingAuraState(lastError: 'some error');
        final cleared = state.copyWith(clearError: true);
        expect(cleared.lastError, isNull);
      });

      test('clearError takes precedence over lastError', () {
        const state = FloatingAuraState(lastError: 'old');
        final cleared = state.copyWith(lastError: 'new', clearError: true);
        expect(cleared.lastError, isNull);
      });

      test('clearPosition clears position', () {
        const position = FloatingAuraOverlayPosition(x: 10.0, y: 20.0);
        const state = FloatingAuraState(position: position);
        final cleared = state.copyWith(clearPosition: true);
        expect(cleared.position, isNull);
      });

      test('clearPosition takes precedence over position', () {
        const position = FloatingAuraOverlayPosition(x: 10.0, y: 20.0);
        const newPosition = FloatingAuraOverlayPosition(x: 30.0, y: 40.0);
        const state = FloatingAuraState(position: position);
        final cleared =
            state.copyWith(position: newPosition, clearPosition: true);
        expect(cleared.position, isNull);
      });

      test('partial update leaves other fields unchanged', () {
        const state = FloatingAuraState(
          status: FloatingAuraOverlayStatus.idle,
          lastError: 'err',
          hasPermission: true,
          isExpanded: true,
        );
        final updated = state.copyWith(
            status: FloatingAuraOverlayStatus.showing);
        expect(updated.status, FloatingAuraOverlayStatus.showing);
        expect(updated.lastError, 'err');
        expect(updated.hasPermission, isTrue);
        expect(updated.isExpanded, isTrue);
      });
    });

    test('toString includes all fields', () {
      const position = FloatingAuraOverlayPosition(x: 10.0, y: 20.0);
      const state = FloatingAuraState(
        status: FloatingAuraOverlayStatus.showing,
        hasPermission: true,
        isExpanded: true,
        position: position,
        lastError: 'err',
      );
      final str = state.toString();
      expect(str, contains('FloatingAuraState'));
      expect(str, contains('showing'));
      expect(str, contains('hasPermission: true'));
      expect(str, contains('isExpanded: true'));
      expect(str, contains('position:'))
      ;
      expect(str, contains('error: err'));
    });
  });

  // ── FloatingAuraOverlayPosition ─────────────────────────────

  group('FloatingAuraOverlayPosition', () {
    test('defaults getter returns expected constant values', () {
      final defaults = FloatingAuraOverlayPosition.defaults;
      expect(defaults.x, FloatingAuraDefaults.defaultPositionX);
      expect(defaults.y, FloatingAuraDefaults.defaultPositionY);
    });

    test('constructor sets x and y', () {
      const pos = FloatingAuraOverlayPosition(x: 100.0, y: 200.0);
      expect(pos.x, 100.0);
      expect(pos.y, 200.0);
    });

    group('fromMap', () {
      test('creates position from valid map with doubles', () {
        final pos = FloatingAuraOverlayPosition.fromMap({
          'x': 50.0,
          'y': 150.0,
        });
        expect(pos.x, 50.0);
        expect(pos.y, 150.0);
      });

      test('creates position from valid map with integers', () {
        final pos = FloatingAuraOverlayPosition.fromMap({
          'x': 50,
          'y': 150,
        });
        expect(pos.x, 50.0);
        expect(pos.y, 150.0);
      });

      test('falls back to defaults when x is null', () {
        final pos = FloatingAuraOverlayPosition.fromMap({
          'y': 150.0,
        });
        expect(pos.x, FloatingAuraDefaults.defaultPositionX);
        expect(pos.y, 150.0);
      });

      test('falls back to defaults when y is null', () {
        final pos = FloatingAuraOverlayPosition.fromMap({
          'x': 50.0,
        });
        expect(pos.x, 50.0);
        expect(pos.y, FloatingAuraDefaults.defaultPositionY);
      });

      test('falls back to defaults when map is empty', () {
        final pos = FloatingAuraOverlayPosition.fromMap({});
        expect(pos.x, FloatingAuraDefaults.defaultPositionX);
        expect(pos.y, FloatingAuraDefaults.defaultPositionY);
      });
    });

    test('toMap returns correct map', () {
      const pos = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
      final map = pos.toMap();
      expect(map, isA<Map<String, dynamic>>());
      expect(map['x'], 50.0);
      expect(map['y'], 150.0);
    });

    test('copyWith creates a new position with updated fields', () {
      const pos = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
      final copied = pos.copyWith(x: 100.0);
      expect(copied.x, 100.0);
      expect(copied.y, 150.0);
    });

    test('copyWith preserves fields when no arguments given', () {
      const pos = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
      final copied = pos.copyWith();
      expect(copied.x, 50.0);
      expect(copied.y, 150.0);
    });

    group('equality', () {
      test('equal positions are equal', () {
        const a = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
        const b = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
        expect(a == b, isTrue);
        expect(a.hashCode, b.hashCode);
      });

      test('different x values are not equal', () {
        const a = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
        const b = FloatingAuraOverlayPosition(x: 51.0, y: 150.0);
        expect(a == b, isFalse);
      });

      test('different y values are not equal', () {
        const a = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
        const b = FloatingAuraOverlayPosition(x: 50.0, y: 151.0);
        expect(a == b, isFalse);
      });

      test('is not equal to other types', () {
        const pos = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
        expect(pos == 'not a position', isFalse);
      });

      test('identical instance is equal', () {
        const pos = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
        expect(pos == pos, isTrue);
      });
    });

    test('toString returns expected format', () {
      const pos = FloatingAuraOverlayPosition(x: 50.0, y: 150.0);
      expect(pos.toString(), 'FloatingAuraOverlayPosition(x: 50.0, y: 150.0)');
    });
  });
}
