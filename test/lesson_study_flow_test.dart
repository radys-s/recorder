import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/study_cards_dao.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';
import 'package:recorder/features/study/lesson_study_panel.dart';
import 'package:recorder/features/study/review_screen.dart';
import 'package:recorder/features/study/study_providers.dart';
import 'package:recorder/learning/scheduler.dart';
import 'package:recorder/learning/study_card_generator.dart';

class _Llm extends LlmProvider {
  _Llm(this.reply, {this.fail = false});
  final String reply;
  final bool fail;
  var calls = 0;

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    calls++;
    if (fail) throw const AiTransientException('limit');
    return LlmCompletion(content: reply);
  }
}

const _notes = '''
Klíčové pojmy:
- OSPF – link-state protokol

Co si zapamatovat:
- RIP má limit 15 skoků.
''';

const _pairs = '{"cards": [{"q": "Kolik skoků zvládne RIP?", "a": "15"}]}';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  late AppDatabase db;
  late int subject;
  late int lesson;
  final day = DateTime(2026, 9, 28, 10);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Drift writes finish on real time, not on the fake clock.
  Future<void> realWork(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester);
  }

  // A drift stream must be unmounted inside the test body.
  void uiTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> seed(
    WidgetTester tester, {
    bool notes = true,
    int cards = 0,
    DateTime? cardsDue,
  }) async {
    await tester.runAsync(() async {
      subject = await db.savedNotesDao.createFolder('Sítě');
      lesson = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: day,
          subjectId: Value(subject),
        ),
      );
      if (notes) {
        await db.meetingNotesDao.markGenerating(
          lesson,
          NotesDepth.standard,
          'm',
        );
        await db.meetingNotesDao.markReady(lesson, _notes);
      }
      if (cards > 0) {
        await db.studyCardsDao.addCards(
          subject,
          [
            for (var i = 0; i < cards; i++)
              StudyItem('Otázka $i', 'Odpověď $i', StudySource.terms),
          ],
          meetingId: lesson,
          now: cardsDue ?? day,
        );
      }
    });
  }

  Future<void> showPanel(WidgetTester tester, {_Llm? llm}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          studyClockProvider.overrideWithValue(() => day),
          studyCardGeneratorProvider.overrideWithValue(
            StudyCardGenerator(db, llm: llm ?? _Llm(_pairs), now: () => day),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LessonStudyPanel(meetingId: lesson, subjectId: subject),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  group('LessonStudyPanel', () {
    uiTest('without cards it offers to make them from this lesson', (
      tester,
    ) async {
      await seed(tester);
      await showPanel(tester);

      expect(find.text('UČENÍ'), findsOneWidget);
      expect(find.text('Vytvořit kartičky'), findsOneWidget);
      expect(
        find.text('Z těchto výpisků zatím nejsou kartičky.'),
        findsOneWidget,
      );
      // The model's work is labelled as such.
      expect(find.textContaining('AI'), findsWidgets);
      expect(find.text('Kartičky předmětu'), findsNothing);
      expect(find.text('Vyzkoušet se před testem'), findsOneWidget);
    });

    uiTest('tap makes cards for this lesson only and says so', (tester) async {
      await seed(tester);
      final llm = _Llm(_pairs);
      await showPanel(tester, llm: llm);

      await tester.tap(find.text('Vytvořit kartičky'));
      await realWork(tester);

      expect(llm.calls, 1);
      expect(
        find.text('Přidáno: 2 kartičky. Zkontroluj je, text psala AI.'),
        findsOneWidget,
      );
      final cards = await tester.runAsync(() => db.select(db.studyCards).get());
      expect(cards, hasLength(2));
      expect(cards!.every((c) => c.meetingId == lesson), isTrue);
      // The panel now shows the lesson's cards instead of the offer.
      expect(find.text('Vytvořit kartičky'), findsNothing);
      expect(find.text('Kartičky předmětu'), findsOneWidget);
      expect(find.textContaining('2 kartičky z této hodiny'), findsOneWidget);
    });

    uiTest('a model that is down says so and creates only the free cards', (
      tester,
    ) async {
      await seed(tester);
      await showPanel(tester, llm: _Llm('', fail: true));

      await tester.tap(find.text('Vytvořit kartičky'));
      await realWork(tester);

      // The „Klíčové pojmy" card needs no model.
      expect(
        find.text('Přidáno: 1 kartička. Zkontroluj je, text psala AI.'),
        findsOneWidget,
      );
    });

    uiTest('a lesson without výpisky makes no cards and asks nothing', (
      tester,
    ) async {
      await seed(tester, notes: false);
      final llm = _Llm(_pairs);
      await showPanel(tester, llm: llm);

      await tester.tap(find.text('Vytvořit kartičky'));
      await realWork(tester);

      expect(llm.calls, 0);
      expect(find.text('Z této hodiny zatím nejsou výpisky.'), findsOneWidget);
      final cards = await tester.runAsync(() => db.select(db.studyCards).get());
      expect(cards, isEmpty);
    });

    uiTest('cards due today open a review of this lesson', (tester) async {
      await seed(tester, cards: 3);
      await showPanel(tester);

      expect(find.text('Opakovat z hodiny'), findsOneWidget);
      expect(find.text('3 kartičky z této hodiny · dnes 3'), findsOneWidget);
      await tester.tap(find.text('Opakovat z hodiny'));
      await settle(tester);

      expect(find.byType(ReviewScreen), findsOneWidget);
      final screen = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
      expect(screen.meetingId, lesson);
      expect(screen.subjectId, subject);
      expect(find.text('Otázka 0'), findsOneWidget);
    });

    uiTest('nothing due today: no review row to tap', (tester) async {
      await seed(tester, cards: 2, cardsDue: day.add(const Duration(days: 5)));
      await showPanel(tester);

      expect(find.text('Dnes nic nečeká'), findsOneWidget);
      expect(find.text('2 kartičky z této hodiny · dnes nic'), findsOneWidget);
      expect(find.text('Opakovat z hodiny'), findsNothing);
      await tester.tap(find.text('Dnes nic nečeká'));
      await settle(tester);
      expect(find.byType(ReviewScreen), findsNothing);
    });
  });

  group('review finish', () {
    Future<void> showReview(WidgetTester tester, {int? lessonScope}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            studyClockProvider.overrideWithValue(() => day),
          ],
          child: MaterialApp(
            home: ReviewScreen(subjectId: subject, meetingId: lessonScope),
          ),
        ),
      );
      await settle(tester);
    }

    uiTest('names the day the next cards come back and offers next steps', (
      tester,
    ) async {
      await seed(tester, cards: 1);
      // A card for later gives the finish screen something to announce.
      await tester.runAsync(
        () => db.studyCardsDao.addCards(subject, const [
          StudyItem('Později', 'x', StudySource.manual),
        ], now: day.add(const Duration(days: 3))),
      );
      await showReview(tester);

      await tester.tap(find.text('Ukázat odpověď'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^Dobře')));
      await settle(tester);

      expect(find.text('Hotovo na dnešek'), findsOneWidget);
      expect(
        find.textContaining('Další kartičky přijdou na řadu'),
        findsOneWidget,
      );
      expect(find.text('CO DÁL'), findsOneWidget);
      expect(find.text('Vyzkoušet se před testem'), findsOneWidget);
      expect(find.text('Kartičky předmětu'), findsOneWidget);
      // Nothing is left due, so no „zbytek předmětu" row.
      expect(find.text('Zopakovat zbytek předmětu'), findsNothing);
    });

    uiTest('a lesson review offers the rest of the subject', (tester) async {
      await seed(tester, cards: 1);
      await tester.runAsync(
        () => db.studyCardsDao.addCards(subject, const [
          StudyItem('Z jiné hodiny', 'x', StudySource.manual),
        ], now: day),
      );
      await showReview(tester, lessonScope: lesson);

      // Only this lesson's card is in the session.
      expect(find.text('Otázka 0'), findsOneWidget);
      await tester.tap(find.text('Ukázat odpověď'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^Dobře')));
      await settle(tester);

      expect(find.text('Hotovo na dnešek'), findsOneWidget);
      expect(find.text('Zopakovat zbytek předmětu'), findsOneWidget);
      expect(find.text('1 kartička čeká dnes'), findsOneWidget);
    });
  });

  group('scheduler sanity', () {
    test('Dobře moves a new card to tomorrow', () {
      final next = schedule(const ReviewState(), ReviewGrade.good, day);
      expect(next.dueAt, DateTime(2026, 9, 29));
    });
  });
}
