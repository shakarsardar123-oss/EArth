import 'package:flutter_test/flutter_test.dart';

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_constants.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_state.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_overlay_position.dart';
import 'package:aura_assistant/core/floating_aura/floating_aura_stub_channel.dart';

void main() {
  // ── FloatingAuraConstants verification ──────────────────────

  group('FloatingAuraConstants', () {
    test('channel name is correct', () {
      expect(
        floatingAuraMethodChannelName,
        'com.aura.aura_assistant/floating_aura_overlay',
      );
    });

    group('FloatingAuraMethodNames', () {
      test('requestPermission is correct', () {
        expect(FloatingAuraMethodNames.requestPermission, 'requestPermission');
      });

      test('openOverlaySettings is correct', () {
        expect(FloatingAuraMethodNames.openOverlaySettings,
            'openOverlaySettings');
      });

      test('hasPermission is correct', () {
        expect(FloatingAuraMethodNames.hasPermission, 'hasPermission');
      });

      test('showOverlay is correct', () {
        expect(FloatingAuraMethodNames.showOverlay, 'showOverlay');
      });

      test('hideOverlay is correct', () {
        expect(FloatingAuraMethodNames.hideOverlay, 'hideOverlay');
      });

      test('updatePosition is correct', () {
        expect(FloatingAuraMethodNames.updatePosition, 'updatePosition');
      });

      test('togglePanel is correct', () {
        expect(FloatingAuraMethodNames.togglePanel, 'togglePanel');
      });

      test('isOverlayVisible is correct', () {
        expect(FloatingAuraMethodNames.isOverlayVisible, 'isOverlayVisible');
      });

      test('isSupported is correct', () {
        expect(FloatingAuraMethodNames.isSupported, 'isSupported');
      });
    });

    group('FloatingAuraEventNames', () {
      test('onOverlayPositionChanged is correct', () {
        expect(FloatingAuraEventNames.onOverlayPositionChanged,
            'onOverlayPositionChanged');
      });

      test('onOverlayPanelToggled is correct', () {
        expect(FloatingAuraEventNames.onOverlayPanelToggled,
            'onOverlayPanelToggled');
      });

      test('onOverlayVisibilityChanged is correct', () {
        expect(FloatingAuraEventNames.onOverlayVisibilityChanged,
            'onOverlayVisibilityChanged');
      });
    });

    group('FloatingAuraDefaults', () {
      test('defaultPositionX is 16.0', () {
        expect(FloatingAuraDefaults.defaultPositionX, 16.0);
      });

      test('defaultPositionY is 100.0', () {
        expect(FloatingAuraDefaults.defaultPositionY, 100.0);
      });

      test('collapsedSize is 56.0', () {
        expect(FloatingAuraDefaults.collapsedSize, 56.0);
      });

      test('expandedWidth is 280.0', () {
        expect(FloatingAuraDefaults.expandedWidth, 280.0);
      });

      test('expandedHeight is 400.0', () {
        expect(FloatingAuraDefaults.expandedHeight, 400.0);
      });
    });
  });

  // ── FloatingAuraStubChannel ────────────────────────────────

  group('FloatingAuraStubChannel', () {
    late FloatingAuraStubChannel stub;

    setUp(() {
      stub = FloatingAuraStubChannel();
    });

    test('isSupported returns false', () {
      expect(stub.isSupported, isFalse);
    });

    test('state returns default FloatingAuraState', () {
      final state = stub.state;
      expect(state, const FloatingAuraState());
      expect(state.status, FloatingAuraOverlayStatus.idle);
      expect(state.hasPermission, isFalse);
      expect(state.isExpanded, isFalse);
      expect(state.position, isNull);
      expect(state.lastError, isNull);
    });

    group('requestPermission', () {
      test('returns failure with requestPermission phase', () async {
        final result = await stub.requestPermission();
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.requestPermission);
            expect(
                f.message, 'Floating overlay is not supported on this platform');
          },
        );
      });
    });

    group('hasPermission', () {
      test('returns failure with requestPermission phase', () async {
        final result = await stub.hasPermission();
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.requestPermission);
          },
        );
      });
    });

    group('showOverlay', () {
      test('returns failure with showOverlay phase', () async {
        final result = await stub.showOverlay(null);
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.showOverlay);
          },
        );
      });
    });

    group('hideOverlay', () {
      test('returns failure with hideOverlay phase', () async {
        final result = await stub.hideOverlay();
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.hideOverlay);
          },
        );
      });
    });

    group('updatePosition', () {
      test('returns failure with updatePosition phase', () async {
        const position = FloatingAuraOverlayPosition(x: 50.0, y: 100.0);
        final result = await stub.updatePosition(position);
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.updatePosition);
          },
        );
      });
    });

    group('togglePanel', () {
      test('returns failure with togglePanel phase', () async {
        final result = await stub.togglePanel();
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.togglePanel);
          },
        );
      });
    });

    group('isOverlayVisible', () {
      test('returns failure with showOverlay phase', () async {
        final result = await stub.isOverlayVisible();
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.showOverlay);
          },
        );
      });
    });

    group('openOverlaySettings', () {
      test('returns failure with openOverlaySettings phase', () async {
        final result = await stub.openOverlaySettings();
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.phase, FloatingAuraOverlayPhase.openOverlaySettings);
          },
        );
      });
    });

    test('dispose completes without error', () async {
      await stub.dispose();
      // If we get here without an exception, the test passes.
    });

    test('all methods have consistent failure messages', () async {
      final methods = <Future<Result<dynamic, FloatingAuraOverlayFailure>>>[
        stub.requestPermission(),
        stub.hasPermission(),
        stub.showOverlay(null),
        stub.hideOverlay(),
        stub.updatePosition(const FloatingAuraOverlayPosition(x: 0.0, y: 0.0)),
        stub.togglePanel(),
        stub.isOverlayVisible(),
        stub.openOverlaySettings(),
      ];

      final results = await Future.wait(methods);
      for (final result in results) {
        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (f) {
            expect(f.message,
                'Floating overlay is not supported on this platform');
          },
        );
      }
    });
  });
}
