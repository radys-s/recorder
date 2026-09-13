import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/motion.dart';
import 'package:recorder/core/widgets/entrance.dart';

/// [Entrance] is the shared entrance animation for both list screens, so the
/// two ways it can go wrong — replaying on every rebuild, and leaving a row
/// stranded at `opacity: 0` for someone who asked for less motion — are worth
/// pinning down here rather than re-checking by eye on each screen.
void main() {
  Widget host({
    required bool enabled,
    bool disableAnimations = false,
    Duration delay = Duration.zero,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Entrance(
          enabled: enabled,
          delay: delay,
          child: const Text('řádek'),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester) =>
      tester.widget<Opacity>(find.byType(Opacity)).opacity;

  testWidgets('fades in and settles fully opaque', (tester) async {
    await tester.pumpWidget(host(enabled: true));

    expect(opacityOf(tester), 0);

    await tester.pump(AppDuration.base ~/ 2);
    final midway = opacityOf(tester);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    expect(find.text('řádek'), findsOneWidget);
  });

  testWidgets('holds off for its stagger delay, then runs', (tester) async {
    await tester.pumpWidget(
      host(enabled: true, delay: const Duration(milliseconds: 200)),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(opacityOf(tester), 0, reason: 'still waiting out the delay');

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
  });

  testWidgets('disabled renders the child with no animation at all',
      (tester) async {
    await tester.pumpWidget(host(enabled: false));

    expect(find.byType(Opacity), findsNothing);
    expect(find.text('řádek'), findsOneWidget);
  });

  testWidgets('reduced motion shows the final state, not a first frame',
      (tester) async {
    await tester.pumpWidget(host(enabled: true, disableAnimations: true));

    // The classic failure this guards against is the row being left invisible
    // rather than being shown immediately.
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('řádek'), findsOneWidget);
    expect(tester.getSize(find.text('řádek')).height, greaterThan(0));
  });

  testWidgets('a rebuild flipping enabled to false does not cut the animation',
      (tester) async {
    // The list screens compute `enabled` from a set of already-seen ids, so it
    // goes false on the very next rebuild — which for a live transcript can
    // easily land inside these 450 ms.
    await tester.pumpWidget(host(enabled: true));
    await tester.pump(AppDuration.base ~/ 3);

    await tester.pumpWidget(host(enabled: false));
    final afterRebuild = opacityOf(tester);
    expect(afterRebuild, lessThan(1), reason: 'still mid-flight');

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
  });
}
