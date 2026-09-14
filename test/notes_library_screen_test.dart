import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/notes_library/notes_library_screen.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A widget test whose tree is unmounted before the body returns. Drift
  /// cancels a stream query on a zero timer, and the framework checks for
  /// pending timers before any tearDown runs, so the unmount has to happen
  /// inside the test itself.
  void libraryTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesLibraryScreen()),
      ),
    );
    await settle(tester);
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  libraryTest('an empty library explains how notes get there', (tester) async {
    await pumpLibrary(tester);

    expect(find.text('Knihovna je zatím prázdná'), findsOneWidget);
    // No folders yet, so no „Bez složky" chip duplicating „Vše".
    expect(chip('Bez složky'), findsNothing);
    expect(find.text('Nová složka'), findsOneWidget);
  });

  libraryTest('folder chips and search narrow the list', (tester) async {
    final dao = db.savedNotesDao;
    final cz = await dao.createFolder('Čeština');
    await dao.saveNote(
      title: 'Slovní druhy',
      content: '- podstatná jména',
      folderId: cz,
    );
    await dao.saveNote(title: 'Rozpočet Q3', content: '- zbývá 1,2 milionu');

    await pumpLibrary(tester);
    expect(find.text('Slovní druhy'), findsOneWidget);
    expect(find.text('Rozpočet Q3'), findsOneWidget);

    await tester.tap(chip('Čeština'));
    await settle(tester);
    expect(find.text('Slovní druhy'), findsOneWidget);
    expect(find.text('Rozpočet Q3'), findsNothing);

    await tester.tap(chip('Bez složky'));
    await settle(tester);
    expect(find.text('Slovní druhy'), findsNothing);
    expect(find.text('Rozpočet Q3'), findsOneWidget);

    await tester.tap(chip('Vše'));
    await tester.enterText(find.byType(TextField), 'rozpocet');
    await settle(tester);
    expect(find.text('Slovní druhy'), findsNothing);
    expect(find.text('Rozpočet Q3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'xyz');
    await settle(tester);
    expect(find.text('Nic nenalezeno'), findsOneWidget);
  });

  libraryTest('a folder deleted while selected falls back to everything',
      (tester) async {
    final dao = db.savedNotesDao;
    final cz = await dao.createFolder('Čeština');
    await dao.saveNote(title: 'Slovní druhy', content: 'a', folderId: cz);
    await dao.saveNote(title: 'Rozpočet Q3', content: 'b');

    await pumpLibrary(tester);
    await tester.tap(chip('Čeština'));
    await settle(tester);
    expect(find.text('Rozpočet Q3'), findsNothing);

    await dao.deleteFolder(cz);
    await settle(tester);

    expect(chip('Čeština'), findsNothing);
    expect(find.text('Slovní druhy'), findsOneWidget);
    expect(find.text('Rozpočet Q3'), findsOneWidget);
  });
}

/// Enough frames for drift's stream to deliver and the entrance to finish.
/// Not `pumpAndSettle`: nothing here loops, but a bounded pump fails loudly
/// instead of hanging if that ever changes.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
