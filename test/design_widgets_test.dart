import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/widgets/async_view.dart';
import 'package:recorder/core/widgets/level_waveform.dart';
import 'package:recorder/core/widgets/pressable.dart';

/// The M36 building blocks: press feedback, the level meter and the loading
/// skeleton — each with the reduced-motion case, which must show the final
/// state rather than nothing.
void main() {
  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  double scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  group('Pressable', () {
    testWidgets('sinks while pressed and comes back on release',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(Pressable(
        child: TextButton(onPressed: () => taps++, child: const Text('karta')),
      )));

      expect(scaleOf(tester), 1);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('karta')),
      );
      await tester.pump();
      expect(scaleOf(tester), 0.97);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1);
      expect(taps, 1, reason: 'the inner button still gets the tap');
    });

    testWidgets('never scales under reduced motion', (tester) async {
      await tester.pumpWidget(host(
        const Pressable(child: SizedBox(width: 80, height: 80)),
        reduced: true,
      ));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump();
      expect(scaleOf(tester), 1);
      await gesture.up();
    });
  });

  group('levelToBar', () {
    test('maps -60..-10 dBFS onto 0..1 and clamps', () {
      expect(levelToBar(0), 0);
      expect(levelToBar(-1), 0);
      expect(levelToBar(double.nan), 0);
      expect(levelToBar(0.001), closeTo(0, 1e-9)); // -60 dBFS
      expect(levelToBar(0.01), closeTo(0.4, 1e-9)); // -40 dBFS
      expect(levelToBar(0.316227766), closeTo(1, 1e-6)); // -10 dBFS
      expect(levelToBar(1), 1);
    });
  });

  group('WaveformPainter', () {
    testWidgets('paints empty, silent and fewer-than-bars histories',
        (tester) async {
      for (final values in [<double>[], [0.0, 0.0], [0.2, 1.0, 0.5]]) {
        await tester.pumpWidget(host(CustomPaint(
          size: const Size(64, 22),
          painter: WaveformPainter(
            values: values,
            bars: 18,
            color: Colors.red,
          ),
        )));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the live meter follows its notifier', (tester) async {
      final level = ValueNotifier((rms: 0.0, peak: 0.0));
      addTearDown(level.dispose);
      await tester.pumpWidget(host(
        LevelWaveform(level: level, color: Colors.red),
      ));

      level.value = (rms: 0.05, peak: 0.1);
      await tester.pump();
      final painter = tester
          .widget<CustomPaint>(find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is WaveformPainter,
          ))
          .painter! as WaveformPainter;
      expect(painter.values, hasLength(1));
      expect(painter.values.single, greaterThan(0));
      expect(find.bySemanticsLabel('Hlasitost mikrofonu'), findsOneWidget);
    });
  });

  group('LoadingSkeleton', () {
    testWidgets('shows its blocks under reduced motion, without a sheen',
        (tester) async {
      await tester.pumpWidget(host(
        const LoadingSkeleton(rows: 3),
        reduced: true,
      ));
      await tester.pump(const Duration(seconds: 2));

      expect(find.bySemanticsLabel('Načítám'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LoadingSkeleton),
          matching: find.byType(Container),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('animates a sheen otherwise', (tester) async {
      await tester.pumpWidget(host(const LoadingSkeleton()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShaderMask), findsOneWidget);
      // Unmount so the repeating controller does not outlive the test.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
