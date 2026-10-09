import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/core/app_route.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/study_cards_dao.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';
import 'package:recorder/features/study/review_screen.dart';
import 'package:recorder/features/study/study_providers.dart';
import 'package:recorder/features/subjects/subject_detail_screen.dart';
import 'package:recorder/features/subjects/subjects_screen.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 15; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('real subject tile has a matching destination Hero during push', (
    t,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final id = await db.savedNotesDao.createFolder('Syntetický předmět');
      await t.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: SubjectsScreen()),
        ),
      );
      await settle(t);
      final subjectHero = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == subjectHeroTag(id),
      );
      expect(subjectHero, findsOneWidget);
      await t.tap(find.text('Syntetický předmět'));
      await t.pump();
      // Header is present before the destination's DB stream has resolved.
      expect(
        find.descendant(
          of: find.byType(SubjectDetailScreen, skipOffstage: false),
          matching: find.byType(Hero, skipOffstage: false),
        ),
        findsOneWidget,
      );
      await settle(t);
      expect(t.takeException(), isNull);
      await t.pageBack();
      await settle(t);
      expect(find.byType(SubjectDetailScreen), findsNothing);
      expect(subjectHero, findsOneWidget);
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      await db.close();
    }
  });
  testWidgets(
    'double grading during save advances and persists just one card',
    (t) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime(2026, 10, 9);
      try {
        final id = await db.savedNotesDao.createFolder('Sítě');
        await db.studyCardsDao.addCards(id, const [
          StudyItem('První otázka', 'První odpověď', StudySource.manual),
          StudyItem('Druhá otázka', 'Druhá odpověď', StudySource.manual),
        ], now: now);
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              studyClockProvider.overrideWithValue(() => now),
            ],
            child: MaterialApp(home: ReviewScreen(subjectId: id)),
          ),
        );
        await settle(t);
        await t.tap(find.text('Ukázat odpověď'));
        await t.pumpAndSettle();
        final grade = find.bySemanticsLabel(RegExp('^Dobře'));
        await t.tap(grade);
        await t.tap(grade);
        await settle(t);
        final rows = await t.runAsync(() => db.select(db.studyCards).get());
        expect(rows!.where((c) => c.reps == 1), hasLength(1));
        expect(rows.where((c) => c.reps == 0), hasLength(1));
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        await db.close();
      }
    },
  );
}
