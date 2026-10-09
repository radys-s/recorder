import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/card_suggestions.dart';
import 'package:recorder/core/app_route.dart';
import 'package:recorder/core/widgets/entrance.dart';
import 'package:recorder/core/widgets/flip_card.dart';
import 'package:recorder/core/widgets/pressable.dart';
import 'package:recorder/core/widgets/result_transition.dart';
import 'package:recorder/core/widgets/stagger_reveal.dart';
import 'package:recorder/core/widgets/text_skeleton.dart';
import 'package:recorder/features/meeting_detail/widgets/card_suggestions_view.dart';

Widget host(Widget child, {bool reduced = false, bool visible = true}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
          enabled: visible,
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  testWidgets(
    'stagger survives repeated builds and reduced motion round trip',
    (t) async {
      Widget view(bool reduced) => host(
        const StaggerReveal(children: [Text('první'), Text('poslední')]),
        reduced: reduced,
      );
      await t.pumpWidget(view(false));
      await t.pump(const Duration(milliseconds: 40));
      for (var i = 0; i < 20; i++) {
        await t.pumpWidget(view(false));
      }
      await t.pumpWidget(view(true));
      await t.pumpWidget(view(false));
      final fades = t.widgetList<FadeTransition>(
        find.descendant(
          of: find.byType(StaggerReveal),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fades.every((f) => f.opacity.value == 1), isTrue);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('flip settles the requested face when motion changes mid-turn', (
    t,
  ) async {
    Widget view(bool flipped, bool reduced) => host(
      FlipCard(
        flipped: flipped,
        front: const Text('front'),
        back: const Text('back'),
      ),
      reduced: reduced,
    );
    await t.pumpWidget(view(false, false));
    await t.pumpWidget(view(true, false));
    await t.pump(const Duration(milliseconds: 30));
    await t.pumpWidget(view(true, true));
    expect(find.text('back'), findsOneWidget);
    expect(find.text('front'), findsNothing);
    await t.pumpWidget(view(true, false));
    expect(find.text('back'), findsOneWidget);
    await t.pumpWidget(view(false, false));
    await t.pump(const Duration(milliseconds: 30));
    await t.pumpWidget(view(true, false));
    await t.pumpAndSettle();
    expect(find.text('back'), findsOneWidget);
    expect(find.text('front'), findsNothing);
  });

  testWidgets('entrance cancels delayed start after reduced motion', (t) async {
    Widget view(bool reduced) => host(
      const Entrance(delay: Duration(seconds: 1), child: Text('row')),
      reduced: reduced,
    );
    await t.pumpWidget(view(false));
    await t.pumpWidget(view(true));
    await t.pumpWidget(view(false));
    final opacity = t.widget<Opacity>(
      find.descendant(
        of: find.byType(Entrance),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1);
    await t.pump(const Duration(seconds: 2));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('result revisions retain state and discard outgoing semantics', (
    t,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    Widget view(int revision, String title, {bool reduced = false}) => host(
      ResultTransition(
        revision: revision,
        child: ListView(
          controller: scroll,
          children: [Text(title), const SizedBox(height: 2000)],
        ),
      ),
      reduced: reduced,
    );
    await t.pumpWidget(view(0, 'old'));
    scroll.jumpTo(120);
    final state = t.state(find.byType(Scrollable));
    await t.pumpWidget(view(1, 'new'));
    await t.pumpWidget(view(2, 'latest'));
    expect(find.text('old'), findsNothing);
    expect(find.text('new'), findsNothing);
    expect(t.state(find.byType(Scrollable)), same(state));
    expect(scroll.offset, 120);
    await t.pumpAndSettle();
    await t.pumpWidget(view(2, 'latest'));
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpWidget(view(3, 'reduced', reduced: true));
    await t.pumpWidget(view(3, 'reduced'));
    expect(
      t
          .widget<Opacity>(
            find.descendant(
              of: find.byType(ResultTransition),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
  });

  testWidgets('skeleton can toggle motion repeatedly and stops offstage', (
    t,
  ) async {
    for (final reduced in [false, true, false, true, false]) {
      await t.pumpWidget(host(const TextSkeleton(), reduced: reduced));
      await t.pump(const Duration(milliseconds: 80));
      expect(t.takeException(), isNull);
    }
    await t.pumpWidget(host(const TextSkeleton(), visible: false));
    await t.pumpAndSettle();
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('press effect preserves long press and scrolling', (t) async {
    var taps = 0;
    var longPresses = 0;
    await t.pumpWidget(
      host(
        ListView(
          children: [
            Pressable(
              child: InkWell(
                onTap: () => taps++,
                onLongPress: () => longPresses++,
                child: const SizedBox(height: 200, child: Text('hold')),
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await t.longPress(find.text('hold'));
    expect(longPresses, 1);
    expect(taps, 0);
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(taps, 0);
    await t.drag(find.byType(ListView), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('dismissed suggestion collapses without semantics or actions', (
    t,
  ) async {
    const card = CardSuggestion(title: 'Téma', content: 'Syntetický obsah.');
    var items = <CardSuggestion>[card];
    late StateSetter update;
    await t.pumpWidget(
      host(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return CardSuggestionsView(
              suggestions: items,
              onAdd: (_) async {},
              onDismiss: (_) async {
                update(() => items = []);
              },
            );
          },
        ),
      ),
    );
    await t.tap(find.byTooltip('Nechci'));
    await t.pump();
    expect(
      find.ancestor(
        of: find.text('Téma'),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    expect(
      find.ancestor(
        of: find.text('Téma'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    await t.pumpAndSettle();
    expect(find.text('Téma'), findsNothing);
  });

  testWidgets(
    'suggestion insertion settles when motion is disabled mid-flight',
    (t) async {
      const card = CardSuggestion(title: 'Nová karta', content: 'Obsah.');
      Widget view(List<CardSuggestion> items, bool reduced) => host(
        CardSuggestionsView(
          suggestions: items,
          onAdd: (_) async {},
          onDismiss: (_) async {},
        ),
        reduced: reduced,
      );
      await t.pumpWidget(view([], false));
      await t.pumpWidget(view([card], false));
      await t.pump(const Duration(milliseconds: 40));
      expect(
        find.descendant(
          of: find.byType(CardSuggestionsView),
          matching: find.byType(SizeTransition),
        ),
        findsWidgets,
      );
      await t.pumpWidget(view([card], true));
      await t.pumpWidget(view([card], false));
      expect(
        find.descendant(
          of: find.byType(CardSuggestionsView),
          matching: find.byType(SizeTransition),
        ),
        findsNothing,
      );
      expect(find.text('Nová karta'), findsOneWidget);
      await t.pumpAndSettle();
    },
  );

  testWidgets('one add in flight; failed save remains retryable', (t) async {
    const card = CardSuggestion(title: 'Téma', content: 'Obsah.');
    var count = 0;
    final pending = Completer<void>();
    await t.pumpWidget(
      host(
        CardSuggestionsView(
          suggestions: const [card],
          onAdd: (_) {
            count++;
            return pending.future;
          },
          onDismiss: (_) async {},
        ),
      ),
    );
    await t.tap(find.text('Přidat'));
    await t.tap(find.text('Přidat'));
    expect(count, 1);
    pending.completeError(StateError('synthetic failure'));
    await t.pumpAndSettle();
    expect(find.text('Téma'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(
      find.text('Kartu se nepodařilo uložit nebo skrýt. Zkus to znovu.'),
      findsOneWidget,
    );
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'shared route preserves Hero and back on $platform reduced=$reduced',
        (t) async {
          final key = GlobalKey<NavigatorState>();
          Widget tile() => Hero(
            tag: subjectHeroTag(7),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.school),
            ),
          );
          await t.pumpWidget(
            MaterialApp(
              navigatorKey: key,
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: child!,
              ),
              home: Scaffold(body: tile()),
            ),
          );
          final route = AppRoute<void>(builder: (_) => Scaffold(body: tile()));
          unawaited(key.currentState!.push(route));
          await t.pump();
          await t.pump(const Duration(milliseconds: 80));
          expect(t.takeException(), isNull);
          await t.pumpAndSettle();
          if (platform == TargetPlatform.iOS) {
            expect(route.popGestureEnabled, isTrue);
            final gesture = await t.startGesture(const Offset(1, 300));
            await gesture.moveBy(const Offset(600, 0));
            await gesture.up();
          } else {
            key.currentState!.pop();
          }
          await t.pumpAndSettle();
          expect(route.isCurrent, isFalse);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
