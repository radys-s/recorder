import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/core/widgets/count_chip.dart';
import 'package:recorder/features/notes_library/saved_note_screen.dart';
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
      // Native compute scans outside fakeAsync's clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
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
    expect(find.text('Knihovna je zatím prázdná'), findsOneWidget);
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

  searchTest('results refresh when stored text changes or is deleted', (
    tester,
  ) async {
    final id = await db.savedNotesDao.saveNote(
      title: 'VLAN',
      content: 'Virtuální síť',
    );
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'virtualni');
    await settle(tester);
    expect(find.text('VLAN'), findsOneWidget);
    await (db.delete(db.savedNotes)..where((t) => t.id.equals(id))).go();
    await settle(tester);
    expect(find.text('VLAN'), findsNothing);
    expect(find.text('Knihovna je zatím prázdná'), findsOneWidget);
  });

  searchTest('subject filter works without typing and can be cleared', (
    tester,
  ) async {
    final folder = await db.savedNotesDao.createFolder('Biologie');
    await db.savedNotesDao.saveNote(
      title: 'Buňka',
      content: 'Jádro',
      folderId: folder,
    );
    await db.savedNotesDao.saveNote(title: 'VLAN', content: 'Síť');
    await pumpSearch(tester);
    await tester.tap(find.byTooltip('Filtrovat podle předmětu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biologie').last);
    await settle(tester);
    expect(find.text('Buňka'), findsOneWidget);
    expect(find.text('VLAN'), findsNothing);
    await tester.tap(find.text('Zrušit filtry'));
    await settle(tester);
    expect(find.text('Nedávná hledání'), findsNothing);
    expect(find.text('PODLE PŘEDMĚTU'), findsOneWidget);
  });

  searchTest('database failure is not presented as no matches', (tester) async {
    await db.savedNotesDao.saveNote(title: 'VLAN', content: 'Síť');
    await pumpSearch(tester);
    await db.customStatement('DROP TABLE saved_notes');
    await tester.enterText(find.byType(TextField), 'vlan');
    await settle(tester);
    expect(find.text('Hledání se nepodařilo načíst.'), findsOneWidget);
    expect(find.text('Zkusit znovu'), findsOneWidget);
    expect(find.text('Nic nenalezeno'), findsNothing);
  });

  searchTest('return from saved note keeps query and result scroll position', (
    tester,
  ) async {
    for (var i = 0; i < 12; i++) {
      await db.savedNotesDao.saveNote(
        title: 'Téma $i',
        content: 'Lokálně uložené výpisky.',
      );
    }
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'tema');
    await settle(tester);
    await tester.ensureVisible(find.text('Téma 3'));
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(
      find.byKey(const PageStorageKey('search-results')),
    );
    final offset = list.controller!.offset;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Téma 3'));
    await settle(tester);
    expect(find.byType(SavedNoteScreen), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'tema',
    );
    expect(list.controller!.offset, closeTo(offset, 1));
  });
}
