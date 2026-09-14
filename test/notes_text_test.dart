import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/widgets/notes_text.dart';

void main() {
  Future<void> pump(WidgetTester tester, String content) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NotesText(content: content)),
        ),
      );

  testWidgets('bullets get a glyph and keep only their text', (tester) async {
    await pump(tester, '- Jan pošle nabídku\n• Eva zavolá\n* hotovo');

    expect(find.text('•'), findsNWidgets(3));
    expect(find.text('Jan pošle nabídku'), findsOneWidget);
    expect(find.text('Eva zavolá'), findsOneWidget);
    expect(find.text('- Jan pošle nabídku'), findsNothing);
  });

  testWidgets('a short line ending in a colon is a heading', (tester) async {
    await pump(tester, 'Úkoly:\n- zavolat');

    final heading = tester.widget<Text>(find.text('Úkoly:'));
    final scheme = Theme.of(tester.element(find.text('Úkoly:'))).colorScheme;
    expect(heading.style?.color, scheme.primary);
  });

  testWidgets('a long sentence ending in a colon stays body text',
      (tester) async {
    final sentence = '${'Tohle je obyčejná věta, která náhodou ' * 2}končí:';
    await pump(tester, sentence);

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text && w.data == sentence),
        findsNothing);
  });

  testWidgets('blank lines become one gap, not several', (tester) async {
    await pump(tester, '\n\nPrvní\n\n\n\nDruhý\n\n');

    final column = tester.widget<Column>(
      find.descendant(
        of: find.byType(NotesText),
        matching: find.byType(Column),
      ),
    );
    // First block, one gap, second block.
    expect(column.children, hasLength(3));
    expect(column.children[1], isA<SizedBox>());
  });
}
