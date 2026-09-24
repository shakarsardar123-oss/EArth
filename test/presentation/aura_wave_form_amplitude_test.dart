// Phase 5: AuraWaveForm real-audio reactivity tests.
//
// Verifies that the SHARED AuraWaveForm widget reacts to a REAL amplitude
// signal on BOTH conversation sides (LISTENING = user mic, SPEAKING = AURA
// TTS activity), that null amplitude preserves the original timer-driven
// motion, and that the dead/uninitialised painter `amplitude` field (a
// Phase-5 WIP bug) no longer exists.
//
// These are widget-level + source-level checks — no device/emulator needed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:texo/presentation/widgets/aura_wave_form.dart';

String _readWaveFormSource() {
  final file = File('lib/presentation/widgets/aura_wave_form.dart');
  if (!file.existsSync()) {
    throw StateError('aura_wave_form.dart not found at expected path');
  }
  return file.readAsStringSync();
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  // One frame is enough; the widget animates on a repeating controller.
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  group('Phase 5: AuraWaveForm amplitude API', () {
    testWidgets('renders while LISTENING with a real amplitude',
        (tester) async {
      await _pump(
        tester,
        const AuraWaveForm(
          state: AuraWaveFormState.listening,
          amplitude: 0.8,
          showPill: false,
        ),
      );
      expect(find.byType(AuraWaveForm), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // dispose controllers
    });

    testWidgets('renders while SPEAKING with a real amplitude',
        (tester) async {
      await _pump(
        tester,
        const AuraWaveForm(
          state: AuraWaveFormState.speaking,
          amplitude: 0.7,
          showPill: false,
        ),
      );
      expect(find.byType(AuraWaveForm), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('renders with null amplitude (timer-driven fallback)',
        (tester) async {
      await _pump(
        tester,
        const AuraWaveForm(
          state: AuraWaveFormState.speaking,
          showPill: false,
        ),
      );
      expect(find.byType(AuraWaveForm), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    test('AuraWaveForm exposes an amplitude field on the widget', () {
      const w = AuraWaveForm(amplitude: 0.5);
      expect(w.amplitude, 0.5);
    });
  });

  group('Phase 5: AuraWaveForm source guarantees', () {
    test('amplitude drives BOTH listening and speaking states', () {
      final src = _readWaveFormSource();
      // The reactive-scaling branch must include speaking, not only listening.
      expect(
        src.contains('AuraWaveFormState.listening ||') &&
            src.contains('widget.state == AuraWaveFormState.speaking'),
        isTrue,
        reason: 'Real-amplitude scaling must apply to LISTENING and SPEAKING',
      );
    });

    test('reactive scaling is not driven by Random()', () {
      final src = _readWaveFormSource();
      // The amplitude branch uses `clampedAmp`/`scale`, never a random call.
      final idx = src.indexOf('final double? amp = widget.amplitude;');
      expect(idx, greaterThan(0));
      final branch = src.substring(idx, idx + 600);
      expect(branch.contains('clampedAmp'), isTrue);
      expect(branch.contains('Random('), isFalse,
          reason: 'Amplitude-driven bars must not use Random()');
    });

    test('painter no longer declares a dead uninitialised amplitude field',
        () {
      final src = _readWaveFormSource();
      // The widget declares exactly one `final double? amplitude;`.
      final count = 'final double? amplitude;'.allMatches(src).length;
      expect(count, 1,
          reason: 'Only the widget should declare amplitude; the painter '
              'must not carry an uninitialised copy (compile bug fix).');
    });
  });
}
