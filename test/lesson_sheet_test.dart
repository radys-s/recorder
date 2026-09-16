import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/subjects/widgets/lesson_sheet.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Unmounts inside the body; see `notes_library_screen_test.dart`.
  void sheetTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  /// A button that opens the start sheet and keeps what it resolved to.
  Future<List<LessonSetup?>> pumpHost(WidgetTester tester, {DateTime? now}) async {
    final results = <LessonSetup?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    results.add(
                    await showStartRecordingSheet(context, ref, now: now)),
                child: const Text('Nahrávat'),
              ),
            ),
          ),
        ),
      ),
    );
    return results;
  }

  sheetTest('without subjects recording starts straight away', (tester) async {
    final results = await pumpHost(tester);

    await tester.tap(find.text('Nahrávat'));
    await settle(tester);

    expect(find.text('Začít'), findsNothing);
    expect(results, hasLength(1));
    expect(results.single?.subjectId, isNull);
    expect(results.single?.cardIds, isEmpty);
  });

  sheetTest('the last lesson\'s subject and cards are proposed',
      (tester) async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    await db.savedNotesDao.createFolder('Matematika');
    final babicka =
        await db.subjectsDao.createCard(subjectId: cz, title: 'Babička');
    await db.subjectsDao.createCard(subjectId: cz, title: 'Máj');
    final lesson = await db.meetingsDao.insertMeeting(MeetingsCompanion.insert(
      title: 'Hodina',
      createdAt: DateTime(2026, 9, 15, 8),
      subjectId: Value(cz),
    ));
    await db.subjectsDao.pinCards(lesson, [babicka]);

    final results = await pumpHost(tester);
    await tester.tap(find.text('Nahrávat'));
    await settle(tester);

    final czChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Čeština'),
    );
    expect(czChip.selected, isTrue);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Babička'))
          .selected,
      isTrue,
    );
    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Máj')).selected,
      isFalse,
    );

    await tester.ensureVisible(find.text('Začít'));
    await tester.tap(find.text('Začít'));
    await settle(tester);

    expect(results, hasLength(1));
    expect(results.single?.subjectId, cz);
    expect(results.single?.cardIds, [babicka]);
    expect(results.single?.rules, isNull);
  });

  sheetTest('the timetable beats the last lesson\'s subject', (tester) async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final math = await db.savedNotesDao.createFolder('Matematika');
    await db.meetingsDao.insertMeeting(MeetingsCompanion.insert(
      title: 'Hodina',
      createdAt: DateTime(2026, 9, 15, 8),
      subjectId: Value(cz),
    ));
    // Wednesday 2026-09-16, 9:55 → maths starts at 10:00.
    await db.subjectsDao.addSlot(
        subjectId: math, weekday: 3, startMinute: 600, endMinute: 645);

    final results = await pumpHost(tester, now: DateTime(2026, 9, 16, 9, 55));
    await tester.tap(find.text('Nahrávat'));
    await settle(tester);

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Matematika'))
          .selected,
      isTrue,
    );
    await tester.ensureVisible(find.text('Začít'));
    await tester.tap(find.text('Začít'));
    await settle(tester);
    expect(results.single?.subjectId, math);
  });

  sheetTest('switching to no subject drops the pinned cards', (tester) async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final babicka =
        await db.subjectsDao.createCard(subjectId: cz, title: 'Babička');
    final lesson = await db.meetingsDao.insertMeeting(MeetingsCompanion.insert(
      title: 'Hodina',
      createdAt: DateTime(2026, 9, 15, 8),
      subjectId: Value(cz),
    ));
    await db.subjectsDao.pinCards(lesson, [babicka]);

    final results = await pumpHost(tester);
    await tester.tap(find.text('Nahrávat'));
    await settle(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bez předmětu'));
    await settle(tester);
    expect(find.widgetWithText(FilterChip, 'Babička'), findsNothing);

    await tester.ensureVisible(find.text('Začít'));
    await tester.tap(find.text('Začít'));
    await settle(tester);

    expect(results.single?.subjectId, isNull);
    expect(results.single?.cardIds, isEmpty);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
