import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/gemini_failure.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';
import 'package:recorder/features/study/exam_prep_screen.dart';
import 'package:recorder/learning/exam_prep.dart';

const _reply = '''
{"summary": "- OSPF je link-state protokol.",
 "questions": [
  {"q": "Jaký typ protokolu je OSPF?",
   "options": ["distance-vector", "link-state", "path-vector", "hybridní"],
   "correct": 1, "explanation": "OSPF zná celou topologii."},
  {"q": "Kolik skoků zvládne RIP?", "a": "15", "explanation": "16 = nedosažitelné."}
 ]}''';

class _Llm extends LlmProvider {
  _Llm([this.reply = _reply, this.error]);
  final String reply;
  final Object? error;
  final models = <String>[];
  final users = <String>[];

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
    final e = error;
    if (e != null) throw e;
    return LlmCompletion(content: reply);
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('parseExamPrep', () {
    test('reads choice and open questions', () {
      final prep = parseExamPrep(_reply)!;
      expect(prep.summary, contains('OSPF'));
      expect(prep.questions, hasLength(2));
      final choice = prep.questions[0];
      expect(choice.kind, ExamQuestionKind.choice);
      expect((choice.correct, choice.answer), (1, 'link-state'));
      expect(prep.questions[1].kind, ExamQuestionKind.open);
      expect(prep.questions[1].answer, '15');
    });

    test('skips malformed questions one by one', () {
      final prep = parseExamPrep('''
{"summary": "", "questions": [
  {"q": "bad index", "options": ["a", "b"], "correct": 2},
  {"q": "one option", "options": ["a"], "correct": 0},
  {"q": "duplicate options", "options": ["a", "A"], "correct": 0},
  {"q": "no answer"},
  {"q": "", "a": "x"},
  "junk",
  {"q": "ok", "a": "yes"},
  {"q": "OK", "a": "again"}
]}''')!;
      expect(prep.questions.map((q) => q.question), ['ok']);
    });

    test('caps the count and rejects replies without questions', () {
      final many = [for (var i = 0; i < 15; i++) '{"q": "q$i", "a": "a"}']
          .join(',');
      expect(
        parseExamPrep('{"questions": [$many]}')!.questions,
        hasLength(kExamQuestionCount),
      );
      expect(parseExamPrep('{"summary": "x", "questions": []}'), isNull);
      expect(parseExamPrep('not json'), isNull);
    });
  });

  group('ExamPrepService', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    final day = DateTime(2026, 9, 28, 10);

    Future<(int, List<SyllabusTopic>)> seed() async {
      final s = await db.savedNotesDao.createFolder('Sítě');
      await db.subjectsDao.replaceTopics(s, [
        const SyllabusTopicDraft(title: 'Směrování', terms: ['OSPF', 'RIP']),
        const SyllabusTopicDraft(title: 'VLAN'),
      ], SyllabusSource.pasted);
      final topics = await db.subjectsDao.topics(s);
      Future<void> lesson(int topicId, String notes, int dayOffset) async {
        final id = await db.meetingsDao.insertMeeting(
          MeetingsCompanion.insert(
            title: 'Hodina',
            createdAt: day.add(Duration(days: dayOffset)),
            subjectId: Value(s),
            topicId: Value(topicId),
          ),
        );
        await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
        await db.meetingNotesDao.markReady(id, notes);
      }

      await lesson(topics[0].id, 'OSPF – link-state', 0);
      await lesson(topics[1].id, 'VLAN – virtuální síť', 1);
      return (s, topics);
    }

    ExamPrepService service(_Llm llm, {LlmProvider? gemini}) => ExamPrepService(
      db,
      llm: llm,
      gemini: gemini,
      hasGeminiKey: () async => gemini != null,
      now: () => day,
    );

    test('reads every lesson, or only the chosen topics', () async {
      final (s, topics) = await seed();
      final llm = _Llm();
      final all = await service(llm).prepare(s);
      expect(all.prep!.questions, hasLength(2));
      expect(llm.users.single, contains('OSPF – link-state'));
      expect(llm.users.single, contains('VLAN – virtuální síť'));
      expect(llm.users.single, contains('celé dosavadní učivo'));

      await service(llm).prepare(s, topicIds: {topics[0].id});
      expect(llm.users.last, contains('OSPF – link-state'));
      expect(llm.users.last, isNot(contains('VLAN – virtuální síť')));
      expect(llm.users.last, contains('- Směrování (pojmy: OSPF, RIP)'));
    });

    test('says why when nothing can be asked', () async {
      final s = await db.savedNotesDao.createFolder('Prázdný');
      final llm = _Llm();
      final r = await service(llm).prepare(s);
      expect(r.prep, isNull);
      expect(r.error, contains('výpisky'));
      expect(llm.users, isEmpty);

      final (s2, _) = await seed();
      final bad = await service(_Llm('{"questions": []}')).prepare(s2);
      expect(bad.error, contains('otázky'));
      final down = await service(_Llm('', const AiTransientException('limit')))
          .prepare(s2);
      expect(down.error, contains('neodpovídají'));
    });

    test('Gemini first; a failure falls back to the router', () async {
      final (s, _) = await seed();
      final gemini = _Llm('', const AiTransientException('busy'));
      final llm = _Llm();
      final r = await service(llm, gemini: gemini).prepare(s);
      expect(r.prep, isNotNull);
      expect(gemini.models, [kGeminiModel]);
      expect(llm.models, [kGroqNotesModel]);

      final bad = _Llm(
        '',
        const AiPermanentException('key', kind: GeminiErrorKind.badKey),
      );
      final fromBadKey = await service(_Llm(), gemini: bad).prepare(s);
      expect(fromBadKey.prep, isNull);
    });

    test('saves the run and turns mistakes into quiz cards', () async {
      final (s, _) = await seed();
      final prep = parseExamPrep(_reply)!;
      final answers = [
        ExamAnswer(prep.questions[0], correct: false, given: 'hybridní'),
        ExamAnswer(prep.questions[1], correct: true),
      ];
      final svc = service(_Llm());
      final noteId = await svc.saveResult(s, prep, answers);
      final note = await (db.select(
        db.savedNotes,
      )..where((t) => t.id.equals(noteId))).getSingle();
      expect(note.folderId, s);
      expect(note.title, 'Před testem – Sítě (28. 9. 2026)');
      expect(note.content, contains('Kvíz (1 z 2):'));
      expect(note.content, contains('- Chyba: Jaký typ protokolu je OSPF?'));

      expect(await svc.addMistakes(s, answers), 1);
      expect(await svc.addMistakes(s, answers), 0);
      final card = (await db.studyCardsDao.dueCards(day)).single;
      expect(card.source, StudySource.quiz);
      expect(card.back, startsWith('link-state'));
    });
  });

  group('ExamPrepScreen', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('summary, quiz, score, mistakes to review', (tester) async {
      late int subject;
      await tester.runAsync(() async {
        subject = await db.savedNotesDao.createFolder('Sítě');
        final id = await db.meetingsDao.insertMeeting(
          MeetingsCompanion.insert(
            title: 'Hodina',
            createdAt: DateTime(2026, 9, 28),
            subjectId: Value(subject),
          ),
        );
        await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
        await db.meetingNotesDao.markReady(id, 'OSPF – link-state');
      });
      final llm = _Llm();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            examPrepServiceProvider.overrideWithValue(
              ExamPrepService(db, llm: llm),
            ),
          ],
          child: MaterialApp(home: ExamPrepScreen(subjectId: subject)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Připravit test'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await settle(tester);
      expect(find.text('Co umět'), findsOneWidget);

      await tester.tap(find.text('Spustit kvíz (2 otázky)'));
      await settle(tester);
      await tester.tap(find.text('hybridní'));
      await settle(tester);
      expect(find.text('OSPF zná celou topologii.'), findsOneWidget);
      await tester.tap(find.text('Další'));
      await settle(tester);

      await tester.tap(find.text('Ukázat odpověď'));
      await settle(tester);
      expect(find.text('15'), findsOneWidget);
      await tester.tap(find.text('Věděl/a jsem'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await settle(tester);
      expect(find.text('1 z 2 správně'), findsOneWidget);

      await tester.tap(find.text('Přidat 1 chybu do opakování'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await settle(tester);
      expect(find.textContaining('Přidáno do opakování'), findsOneWidget);

      // The result is not a dead end: it says what to do next.
      expect(find.text('CO DÁL'), findsOneWidget);
      expect(find.text('Opakovat teď'), findsOneWidget);
      expect(find.text('Kartičky předmětu'), findsOneWidget);
      await tester.tap(find.text('Zkusit nový kvíz'));
      await settle(tester);
      expect(find.text('Připravit test'), findsOneWidget);
      expect(find.text('CO DÁL'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
