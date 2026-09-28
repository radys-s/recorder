import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/study_cards_dao.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';
import 'package:recorder/features/study/review_screen.dart';
import 'package:recorder/features/study/study_providers.dart';
import 'package:recorder/learning/scheduler.dart';
import 'package:recorder/learning/study_card_generator.dart';

class _Llm extends LlmProvider {
  _Llm(this.reply, {this.fail = false});
  final String reply;
  final bool fail;
  final users = <String>[];
  final models = <String>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    models.add(model);
    users.add(messages.last.content);
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

const _pairs =
    '{"cards": [{"q": "Kolik skoků zvládne RIP?", "a": "15"}, '
    '{"q": "ospf", "a": "duplicate of a term"}]}';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final day = DateTime(2026, 9, 28, 10);

  group('StudyCardsDao', () {
    test(
      'adds cards once per question, ignoring case and diacritics',
      () async {
        final s = await db.savedNotesDao.createFolder('Sítě');
        final dao = db.studyCardsDao;
        expect(
          await dao.addCards(s, const [
            StudyItem('Směrování', 'a', StudySource.terms),
            StudyItem('smerovani', 'b', StudySource.remember),
            StudyItem(' ', 'c', StudySource.manual),
            StudyItem('VLAN', '', StudySource.manual),
          ], now: day),
          1,
        );
        final other = await db.savedNotesDao.createFolder('Čeština');
        expect(
          await dao.addCards(other, const [
            StudyItem('Směrování', 'jinde', StudySource.manual),
          ], now: day),
          1,
        );
      },
    );

    test(
      'due today: suspended and later cards stay out, subject filters',
      () async {
        final a = await db.savedNotesDao.createFolder('A');
        final b = await db.savedNotesDao.createFolder('B');
        final dao = db.studyCardsDao;
        await dao.addCards(a, const [
          StudyItem('q1', 'a', StudySource.manual),
          StudyItem('q2', 'a', StudySource.manual),
          StudyItem('q3', 'a', StudySource.manual),
        ], now: day);
        await dao.addCards(b, const [
          StudyItem('q4', 'a', StudySource.manual),
        ], now: day);
        final cards = await dao.dueCards(day, subjectId: a);
        await dao.setSuspended(cards[0].id, true);
        await dao.applyReview(
          cards[1].id,
          schedule(const ReviewState(), ReviewGrade.good, day),
        );

        expect(await dao.watchDueCount(day).first, 2);
        expect(await dao.watchDueCount(day, subjectId: a).first, 1);
        // Tomorrow the reviewed one is due again.
        final tomorrow = day.add(const Duration(days: 1));
        expect(await dao.watchDueCount(tomorrow, subjectId: a).first, 2);
        final stats = await dao.watchStats(a, day).first;
        expect((stats.total, stats.due), (3, 1));
      },
    );

    test(
      'lesson and note deletes keep the cards, subject delete removes them',
      () async {
        final s = await db.savedNotesDao.createFolder('Sítě');
        final meeting = await db.meetingsDao.insertMeeting(
          MeetingsCompanion.insert(
            title: 'Hodina',
            createdAt: day,
            subjectId: Value(s),
          ),
        );
        final note = await db.savedNotesDao.saveNote(
          title: 'N',
          content: 'x',
          folderId: s,
        );
        await db.studyCardsDao.addCards(
          s,
          const [StudyItem('q', 'a', StudySource.manual)],
          meetingId: meeting,
          noteId: note,
          now: day,
        );
        await db.meetingsDao.deleteMeeting(meeting);
        await db.savedNotesDao.deleteNote(note);
        final card = (await db.studyCardsDao.dueCards(day)).single;
        expect((card.meetingId, card.noteId), (null, null));

        await db.studyCardsDao.deleteCard(card.id);
        await db.studyCardsDao.restore(card);
        expect(await db.studyCardsDao.dueCards(day), hasLength(1));

        await db.subjectsDao.deleteSubject(s);
        expect(await db.studyCardsDao.dueCards(day), isEmpty);
      },
    );

    test('an edit may not duplicate another question', () async {
      final s = await db.savedNotesDao.createFolder('Sítě');
      await db.studyCardsDao.addCards(s, const [
        StudyItem('A', 'a', StudySource.manual),
        StudyItem('B', 'b', StudySource.manual),
      ], now: day);
      final cards = await db.studyCardsDao.dueCards(day);
      await expectLater(
        db.studyCardsDao.updateCard(cards[1].id, front: 'a', back: 'x'),
        throwsA(anything),
      );
      await db.studyCardsDao.updateCard(cards[1].id, front: 'C', back: 'c');
      expect((await db.studyCardsDao.dueCards(day))[1].front, 'C');
    });
  });

  group('StudyCardGenerator', () {
    Future<int> lesson({bool subject = true}) async {
      final s = await db.savedNotesDao.createFolder('Sítě');
      return db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: day,
          subjectId: Value(subject ? s : null),
        ),
      );
    }

    StudyCardGenerator gen(_Llm llm) =>
        StudyCardGenerator(db, llm: llm, now: () => day);

    test(
      'lesson notes: free term cards plus model pairs, no duplicates',
      () async {
        final id = await lesson();
        final llm = _Llm(_pairs);
        expect(await gen(llm).fromLessonNotes(id, _notes), 2);
        expect(llm.models, [kGroqNotesModel]);
        expect(llm.users.single, contains('RIP má limit 15 skoků.'));
        expect(llm.users.single, contains('OSPF'));
        final cards = await db.studyCardsDao.dueCards(day);
        expect(
          cards.map((c) => c.front),
          containsAll(['OSPF', 'Kolik skoků zvládne RIP?']),
        );
        expect(cards.first.meetingId, id);
      },
    );

    test('a failed model call keeps the term cards', () async {
      final id = await lesson();
      expect(await gen(_Llm('', fail: true)).fromLessonNotes(id, _notes), 1);
    });

    test('a lesson without a subject makes nothing and asks nothing', () async {
      final id = await lesson(subject: false);
      final llm = _Llm(_pairs);
      expect(await gen(llm).fromLessonNotes(id, _notes), 0);
      expect(llm.users, isEmpty);
    });

    test('a saved note without sections goes to the model whole', () async {
      final s = await db.savedNotesDao.createFolder('Dějepis');
      final id = await db.savedNotesDao.saveNote(
        title: 'Husité',
        content: 'Jan Žižka vedl husity.',
        folderId: s,
      );
      final note = await (db.select(
        db.savedNotes,
      )..where((t) => t.id.equals(id))).getSingle();
      final llm = _Llm('{"cards": [{"q": "Kdo vedl husity?", "a": "Žižka"}]}');
      expect(await gen(llm).fromSavedNote(note), 1);
      expect(llm.users.single, contains('Jan Žižka vedl husity.'));
      expect((await db.studyCardsDao.dueCards(day)).single.noteId, id);

      // Nothing new and the model down: the screen hears why.
      await expectLater(
        gen(_Llm('', fail: true)).fromSavedNote(note),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('ReviewScreen', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    void reviewTest(String description, WidgetTesterCallback body) {
      testWidgets(description, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            studyClockProvider.overrideWithValue(() => day),
          ],
          child: const MaterialApp(home: ReviewScreen()),
        ),
      );
      await settle(tester);
    }

    reviewTest('question, answer, grade, and Znovu comes round again', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final s = await db.savedNotesDao.createFolder('Sítě');
        await db.studyCardsDao.addCards(s, const [
          StudyItem('Co je OSPF?', 'Link-state protokol', StudySource.terms),
        ], now: day);
      });
      await pump(tester);

      expect(find.text('Co je OSPF?'), findsOneWidget);
      expect(find.text('Link-state protokol'), findsNothing);
      await tester.tap(find.text('Ukázat odpověď'));
      await settle(tester);
      expect(find.text('Link-state protokol'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^Znovu')));
      await settle(tester);
      // Back in the queue as card 2 of 2.
      expect(find.text('Co je OSPF?'), findsOneWidget);
      await tester.tap(find.text('Ukázat odpověď'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^Dobře')));
      await settle(tester);
      expect(find.text('Hotovo na dnešek'), findsOneWidget);

      final card = await tester.runAsync(
        () => db.select(db.studyCards).getSingle(),
      );
      expect(card!.reps, 1);
      expect(card.dueAt, DateTime(2026, 9, 29));
    });

    reviewTest('nothing due says so', (tester) async {
      await pump(tester);
      expect(find.text('Dnes není co opakovat'), findsOneWidget);
    });
  });
}
