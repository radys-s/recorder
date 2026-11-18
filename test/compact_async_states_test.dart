import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/widgets/async_view.dart';
import 'package:recorder/core/widgets/empty_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Center(child: SizedBox(width: 320, height: 160, child: child)),
        ),
      ),
    ),
  );

  testWidgets('loading skeleton fits the space left above a keyboard', (
    tester,
  ) async {
    await pump(tester, const LoadingSkeleton());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an error can be scrolled to its retry action', (tester) async {
    var retried = false;
    await pump(
      tester,
      AsyncView<int>(
        value: AsyncValue.error(StateError('synthetic'), StackTrace.empty),
        message: 'Přepis se nepodařilo načíst. Záznam zůstává uložený.',
        onRetry: () => retried = true,
        builder: (_) => const SizedBox(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Zkusit znovu'));
    await tester.pump();
    await tester.tap(find.text('Zkusit znovu'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty state keeps its action reachable in a short viewport', (
    tester,
  ) async {
    var tapped = false;
    await pump(
      tester,
      EmptyState(
        icon: Icons.subject,
        title: 'Zatím tu není žádný přepis',
        message: 'Zvuk je bezpečně uložený. Přepis čeká na připojení.',
        action: TextButton(
          onPressed: () => tapped = true,
          child: const Text('Otevřít nastavení'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Otevřít nastavení'));
    await tester.pump();
    await tester.tap(find.text('Otevřít nastavení'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
