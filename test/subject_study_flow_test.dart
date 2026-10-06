import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/study_cards_dao.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';
import 'package:recorder/features/study/review_screen.dart';
import 'package:recorder/features/study/study_entry.dart';
import 'package:recorder/features/study/study_providers.dart';
import 'package:recorder/features/subjects/subject_detail_screen.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  late AppDatabase db;
  late int subject;
  final day = DateTime(2026, 9, 28, 10);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // A drift stream must be unmounted inside the test body.
  void uiTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<int> lesson(
    WidgetTester tester, {
    DateTime? at,
    bool notes = false,
    int cards = 0,
    DateTime? cardsDue,
    String title = 'Hodina',
  }) async {
    final id = await tester.runAsync(() async {
      final id = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: title,
          createdAt: at ?? day,
          subjectId: Value(subject),
        ),
      );
      if (notes) {
        await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
        await db.meetingNotesDao.markReady(id, 'Výpisky');
      }
      if (cards > 0) {
        await db.studyCardsDao.addCards(
          subject,
          [
            for (var i = 0; i < cards; i++)
              StudyItem('Otázka $id/$i', 'Odpověď', StudySource.terms),
          ],
          meetingId: id,
          now: cardsDue ?? day,
        );
      }
      return id;
    });
    return id!;
  }

  Future<void> begin(WidgetTester tester) async {
    subject = (await tester.runAsync(
      () => db.savedNotesDao.createFolder('Sítě'),
    ))!;
  }

  List<Override> overrides() => [
    appDatabaseProvider.overrideWithValue(db),
    studyClockProvider.overrideWithValue(() => day),
  ];

  /// The section with the subject's lessons as the Přehled tab hands them in.
  Future<void> showSection(WidgetTester tester) async {
    final lessons = await tester.runAsync(
      () => db.subjectsDao.watchLessons(subject).first,
    );
    final withNotes = await tester.runAsync(
      () => db.meetingNotesDao.watchMeetingIdsWithNotes().first,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SubjectStudySection(
                subjectId: subject,
                lessons: lessons!,
                withNotes: withNotes!,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  group('SubjectStudySection „Co teď"', () {
    uiTest('no lesson yet asks for the first recording', (tester) async {
      await begin(tester);
      await showSection(tester);
      expect(find.text('CO TEĎ'), findsOneWidget);
      expect(find.text('Nahraj první hodinu'), findsOneWidget);
      expect(
        find.text('Z výpisků hodiny se pak udělají kartičky na opakování.'),
        findsOneWidget,
      );
    });

    uiTest('a lesson without výpisky asks for výpisky', (tester) async {
      await begin(tester);
      await lesson(tester);
      await showSection(tester);
      expect(find.text('Vytvoř výpisky z hodiny'), findsOneWidget);
    });

    uiTest('výpisky without cards point to making cards', (tester) async {
      await begin(tester);
      await lesson(tester, notes: true);
      await showSection(tester);
      expect(find.text('Udělej kartičky z výpisků'), findsOneWidget);
      expect(
        find.text('Jedna hodina má výpisky, ale žádné kartičky.'),
        findsOneWidget,
      );
    });

    uiTest('cards due today beat everything and open a subject review', (
      tester,
    ) async {
      await begin(tester);
      await lesson(tester, notes: true, cards: 2);
      await showSection(tester);

      expect(find.text('Zopakuj 2 kartičky'), findsOneWidget);
      await tester.tap(find.text('Zopakuj 2 kartičky'));
      await settle(tester);

      final screen = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
      expect(screen.subjectId, subject);
      expect(screen.meetingId, isNull);
    });

    uiTest('everything done and nothing due leads to the quiz', (tester) async {
      await begin(tester);
      await lesson(
        tester,
        notes: true,
        cards: 1,
        cardsDue: day.add(const Duration(days: 5)),
      );
      await showSection(tester);
      expect(find.text('Vyzkoušej se před testem'), findsOneWidget);
      expect(find.textContaining('Dnes nic nečeká'), findsWidgets);
    });
  });

  group('Hodiny tab', () {
    Future<void> showTab(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            home: SubjectDetailScreen(subjectId: subject, initialTab: 1),
          ),
        ),
      );
      await settle(tester);
    }

    uiTest('every lesson says what it holds for learning', (tester) async {
      await begin(tester);
      await lesson(
        tester,
        at: DateTime(2026, 9, 28, 9),
        notes: true,
        cards: 3,
        title: 'Směrování',
      );
      await lesson(
        tester,
        at: DateTime(2026, 9, 21, 9),
        notes: true,
        title: 'VLAN',
      );
      await lesson(tester, at: DateTime(2026, 9, 14, 9), title: 'Úvod');
      await showTab(tester);

      expect(find.text('HODINY A LÁTKA'), findsOneWidget);
      expect(
        find.textContaining('Výpisky · 3 kartičky · dnes 3'),
        findsOneWidget,
      );
      expect(find.textContaining('Výpisky · bez kartiček'), findsOneWidget);
      expect(find.textContaining('Bez výpisků'), findsOneWidget);
    });
  });
}
