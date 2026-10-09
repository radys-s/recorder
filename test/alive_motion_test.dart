import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/widgets/count_up.dart';
import 'package:recorder/core/widgets/flip_card.dart';
import 'package:recorder/core/widgets/notes_text.dart';
import 'package:recorder/core/widgets/pop_in.dart';
import 'package:recorder/core/widgets/pressable.dart';
import 'package:recorder/core/widgets/stagger_reveal.dart';
import 'package:recorder/core/widgets/text_skeleton.dart';

void main() {
  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: child),
    ),
  );

  // The route and Scaffold bring their own fades; only count the widget's.
  Finder fadesIn(Type owner) => find.descendant(
    of: find.byType(owner),
    matching: find.byType(FadeTransition),
  );

  double opacityOf(WidgetTester tester, Finder of) {
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: of, matching: find.byType(FadeTransition)).first,
    );
    return fade.opacity.value;
  }

  group('FlipCard', () {
    testWidgets('shows one face at a time and turns on flip', (tester) async {
      var flipped = false;
      late StateSetter set;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (_, setState) {
              set = setState;
              return FlipCard(
                front: const Text('přední'),
                back: const Text('zadní'),
                flipped: flipped,
              );
            },
          ),
        ),
      );
      expect(find.text('přední'), findsOneWidget);
      expect(find.text('zadní'), findsNothing);

      set(() => flipped = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      // Still on the way: the front is turned away from us only after halfway.
      expect(find.text('přední'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('přední'), findsNothing);
      expect(find.text('zadní'), findsOneWidget);

      set(() => flipped = false);
      await tester.pumpAndSettle();
      expect(find.text('přední'), findsOneWidget);
      expect(find.text('zadní'), findsNothing);
    });

    testWidgets('reduced motion jumps straight to the final face', (
      tester,
    ) async {
      var flipped = false;
      late StateSetter set;
      await tester.pumpWidget(
        host(
          reduced: true,
          StatefulBuilder(
            builder: (_, setState) {
              set = setState;
              return FlipCard(
                front: const Text('přední'),
                back: const Text('zadní'),
                flipped: flipped,
              );
            },
          ),
        ),
      );
      set(() => flipped = true);
      await tester.pump();
      expect(find.text('zadní'), findsOneWidget);
      expect(find.text('přední'), findsNothing);
    });
  });

  group('PopIn', () {
    testWidgets('ends fully visible at full size', (tester) async {
      await tester.pumpWidget(host(const PopIn(child: Text('ok'))));
      await tester.pumpAndSettle();
      expect(find.text('ok'), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(PopIn), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('reduced motion adds no wrapper at all', (tester) async {
      await tester.pumpWidget(
        host(reduced: true, const PopIn(child: Text('ok'))),
      );
      expect(find.text('ok'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PopIn),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  group('StaggerReveal and NotesText.reveal', () {
    setUp(NotesText.resetReveals);

    testWidgets('children are in the tree at once and end fully opaque', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const StaggerReveal(children: [Text('jedna'), Text('dvě')]),
        ),
      );
      expect(find.text('jedna'), findsOneWidget);
      expect(find.text('dvě'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, find.text('jedna')), 1);
      expect(opacityOf(tester, find.text('dvě')), 1);
    });

    testWidgets('reduced motion draws no fades', (tester) async {
      await tester.pumpWidget(
        host(
          reduced: true,
          const StaggerReveal(children: [Text('jedna'), Text('dvě')]),
        ),
      );
      expect(find.text('jedna'), findsOneWidget);
      expect(fadesIn(StaggerReveal), findsNothing);
    });

    testWidgets('animate false renders final state with no controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const StaggerReveal(
            animate: false,
            children: [Text('jedna'), Text('dvě')],
          ),
        ),
      );
      expect(fadesIn(StaggerReveal), findsNothing);
    });

    testWidgets('a note reveals once, a second showing is static', (
      tester,
    ) async {
      const text = 'Téma:\n- první\n- druhý\n- třetí';
      await tester.pumpWidget(
        host(const NotesText(content: text, reveal: true)),
      );
      expect(find.text('první'), findsOneWidget);
      expect(fadesIn(StaggerReveal), findsWidgets);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, find.text('třetí')), 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(const NotesText(content: text, reveal: true)),
      );
      expect(find.text('první'), findsOneWidget);
      expect(find.byType(StaggerReveal), findsOneWidget);
      // Same text again: no controller, no fades.
      expect(fadesIn(StaggerReveal), findsNothing);
    });

    testWidgets('without reveal the notes stay a plain column', (tester) async {
      await tester.pumpWidget(
        host(const NotesText(content: 'Téma:\n- první\n- druhý')),
      );
      expect(find.byType(StaggerReveal), findsNothing);
      expect(find.text('první'), findsOneWidget);
    });
  });

  group('Pressable', () {
    testWidgets('does not swallow the tap of the button inside', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          Pressable(
            child: FilledButton(
              onPressed: () => taps++,
              child: const Text('Ukázat'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ukázat'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('CountUp', () {
    testWidgets('ends on the target value', (tester) async {
      await tester.pumpWidget(host(const CountUp(value: 7)));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('reduced motion shows the target at once', (tester) async {
      await tester.pumpWidget(host(reduced: true, const CountUp(value: 7)));
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('TextSkeleton', () {
    testWidgets('reduced motion is static and settles', (tester) async {
      await tester.pumpWidget(host(reduced: true, const TextSkeleton()));
      await tester.pumpAndSettle();
      expect(find.byType(TextSkeleton), findsOneWidget);
    });

    testWidgets('animated one renders without errors', (tester) async {
      await tester.pumpWidget(host(const TextSkeleton(lines: 3)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TextSkeleton), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
