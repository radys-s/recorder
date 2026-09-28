import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/core/widgets/count_chip.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/search/search_screen.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Unmounted inside the body: drift cancels stream queries on a zero timer
  /// and pending timers are checked before any tearDown runs.
  void searchTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await settle(tester);
  }

  searchTest('an empty start explains what is searched', (tester) async {
    await pumpSearch(tester);
    expect(find.text('Hledej v hodinách'), findsOneWidget);
  });

  searchTest('a recent search is offered and runs on tap', (tester) async {
    await db.preferencesDao.addRecentSearch('Babička');
    await db.savedNotesDao.saveNote(
      title: 'Babička – rozbor',
      content: 'Viktorka a Proško',
    );
    await pumpSearch(tester);

    expect(find.text('NEDÁVNÁ HLEDÁNÍ'), findsOneWidget);
    await tester.tap(find.text('Babička'));
    await settle(tester);

    expect(find.text('Babička – rozbor'), findsOneWidget);
  });

  searchTest('kind chips narrow the results to one group', (tester) async {
    final folder = await db.savedNotesDao.createFolder('Čeština');
    await db.savedNotesDao.saveNote(
      title: 'Máj',
      content: 'Romantismus u Máchy',
      folderId: folder,
    );
    await db.subjectsDao.createCard(
      subjectId: folder,
      title: 'Máj – Karel Hynek Mácha',
      content: 'Lyrickoepická báseň, romantismus',
    );
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'romantismus');
    await settle(tester);

    expect(find.byType(CountChip), findsNWidgets(3));
    expect(find.text('Máj'), findsOneWidget);
    expect(find.text('Máj – Karel Hynek Mácha'), findsOneWidget);

    await tester.tap(find.widgetWithText(CountChip, 'Karty'));
    await settle(tester);
    expect(find.text('Máj'), findsNothing);
    expect(find.text('Máj – Karel Hynek Mácha'), findsOneWidget);
  });

  searchTest('a subject chip searches for that subject', (tester) async {
    final folder = await db.savedNotesDao.createFolder('Dějepis');
    await db.savedNotesDao.saveNote(
      title: 'Husité',
      content: 'Dějepis: Jan Žižka',
      folderId: folder,
    );
    await pumpSearch(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Dějepis'));
    await settle(tester);

    expect(find.text('Husité'), findsOneWidget);
  });

  searchTest('submitting remembers the query', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'OSPF');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    expect(await db.preferencesDao.recentSearches(), ['OSPF']);
  });
}
