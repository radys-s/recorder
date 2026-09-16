import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/subjects/subjects_screen.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Unmounts inside the body; see `notes_library_screen_test.dart`.
  void subjectsTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> pumpSubjects(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SubjectsScreen()),
      ),
    );
    await settle(tester);
  }

  subjectsTest('no subjects explains what a subject is for', (tester) async {
    await pumpSubjects(tester);

    expect(find.text('Zatím žádné předměty'), findsOneWidget);
    expect(find.text('Nový předmět'), findsOneWidget);
  });

  subjectsTest('the tab has a collapsing large title and a tile grid',
      (tester) async {
    await db.savedNotesDao.createFolder('Čeština');
    await pumpSubjects(tester);

    expect(find.byType(SliverAppBar), findsOneWidget);
    // The large variant renders the title twice: expanded and collapsed.
    expect(find.text('Předměty'), findsNWidgets(2));
    expect(find.byType(SliverGrid), findsOneWidget);
  });

  subjectsTest('a subject lists its cards and opens them', (tester) async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    await db.subjectsDao.createCard(
      subjectId: cz,
      title: 'Babička',
      content: 'Božena Němcová, venkovská próza',
    );
    await db.subjectsDao.createCard(subjectId: cz, title: 'Máj');

    await pumpSubjects(tester);
    expect(find.text('Čeština'), findsOneWidget);
    expect(find.textContaining('2 karty'), findsOneWidget);

    await tester.tap(find.text('Čeština'));
    await settle(tester);

    expect(find.text('Babička'), findsOneWidget);
    expect(find.text('Máj'), findsOneWidget);
    expect(find.text('Bez obsahu'), findsOneWidget);
    expect(find.text('Nová karta'), findsOneWidget);

    await tester.tap(find.text('Babička'));
    await settle(tester);
    expect(find.text('Upravit kartu'), findsOneWidget);
  });

  subjectsTest('a deleted subject leaves the detail screen empty-handed',
      (tester) async {
    final cz = await db.savedNotesDao.createFolder('Čeština');

    await pumpSubjects(tester);
    await tester.tap(find.text('Čeština'));
    await settle(tester);

    await db.subjectsDao.deleteSubject(cz);
    await settle(tester);

    expect(find.text('Předmět už neexistuje'), findsOneWidget);
  });
}

/// Enough frames for drift's stream to deliver and the entrance to finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
