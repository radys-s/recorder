import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/lesson_context_source.dart';
import 'package:recorder/ai/lesson_notes_input.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/notes_generator.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';

class _Llm extends LlmProvider {
  _Llm(this.reply);
  final Object Function(int index) reply;
  final calls =
      <({String model, String system, String user, int? maxTokens})>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    final answer = reply(calls.length);
    calls.add((
      model: model,
      system: messages.first.content,
      user: messages.last.content,
      maxTokens: maxTokens,
    ));
    if (answer is Exception) throw answer;
    return LlmCompletion(content: answer as String);
  }
}

const _lesson = LessonNotesInput(
  subjectName: 'Čeština',
  cardTitles: ['Babička'],
  context: ['Čteme úryvek o Viktorce'],
  photos: ['Realismus – 19. století'],
  questions: [(question: 'Kdo byl Proško?', answer: 'Myslivec.')],
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> meeting({
    int? subjectId,
    List<String> segments = const ['Dnes Babička.'],
  }) async {
    final id = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: 'Hodina',
        createdAt: DateTime(2026, 9, 16, 8),
        subjectId: Value(subjectId),
      ),
    );
    for (var i = 0; i < segments.length; i++) {
      await db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: id,
          sequence: i,
          startMs: i * 10000,
          endMs: (i + 1) * 10000,
          content: Value(segments[i]),
          status: SegmentStatus.transcribed,
          localAudioPath: 'x.wav',
          createdAt: DateTime(2026, 9, 16),
        ),
      );
    }
    return id;
  }

  group('lessonNotesBlocks', () {
    test('labelled blocks in order, empty ones skipped', () {
      final text = lessonNotesBlocks(_lesson);
      expect(text, contains('Kontext od studenta:\n- Čteme úryvek o Viktorce'));
      expect(
        text,
        contains('Fotky tabule a prezentace:\n--- fotka 1 ---\nRealismus'),
      );
      expect(text, contains('- Otázka: Kdo byl Proško?\n  Odpověď: Myslivec.'));
      expect(lessonNotesBlocks(const LessonNotesInput(subjectName: 'X')), '');
      expect(
        lessonNotesBlocks(
          const LessonNotesInput(subjectName: 'X', context: ['a']),
        ),
        isNot(contains('Fotky')),
      );
    });

    test('a budget is shared between blocks and keeps items whole', () {
      final input = LessonNotesInput(
        subjectName: 'X',
        context: [for (var i = 0; i < 20; i++) 'kontext $i ${'k' * 80}'],
        photos: ['fotka ${'f' * 100}'],
      );
      final text = lessonNotesBlocks(input, maxChars: 600);
      expect(text, contains('fotka'));
      expect(text, contains('kontext 0'));
      expect(text, isNot(contains('kontext 19')));
      expect(text.length, lessThan(700));
    });

    test('user message: subject, cards, transcript, blocks', () {
      final msg = lessonUserMessage(' přepis ', _lesson);
      expect(
        msg,
        startsWith(
          'Předmět: Čeština\nKarty k hodině: Babička\n\nPřepis:\npřepis',
        ),
      );
      expect(lessonNotesPrompt(NotesDepth.standard), contains('Klíčové pojmy'));
    });
  });

  group('NotesGenerator for a lesson', () {
    Future<(_Llm, _Llm, List<String>)> run({
      required int id,
      bool key = true,
      Object Function(int)? geminiReply,
      LessonNotesInput? lesson = _lesson,
    }) async {
      final groq = _Llm((_) => '- Groq výpisky');
      final gemini = _Llm(geminiReply ?? (_) => '- Gemini výpisky');
      final after = <String>[];
      await NotesGenerator(
        groq,
        db.transcriptSegmentsDao,
        db.meetingNotesDao,
        lessonFor: (_) async => lesson,
        gemini: gemini,
        hasGeminiKey: () async => key,
        onLessonNotes: (_, notes) async => after.add(notes),
      ).generate(meetingId: id, depth: NotesDepth.standard);
      return (groq, gemini, after);
    }

    test('with a key: one Gemini call over every labelled block', () async {
      final id = await meeting();
      final (groq, gemini, after) = await run(id: id);

      expect(groq.calls, isEmpty);
      final call = gemini.calls.single;
      expect(call.model, kGeminiModel);
      expect(call.system, contains('Klíčové pojmy'));
      expect(call.user, contains('Přepis:\nDnes Babička.'));
      expect(call.user, contains('Realismus – 19. století'));
      expect(call.user, contains('Kdo byl Proško?'));
      final row = (await db.meetingNotesDao.forMeeting(id))!;
      expect(row.content, '- Gemini výpisky');
      expect(row.model, kGeminiModel);
      expect(after, ['- Gemini výpisky']);
    });

    test('Gemini failing falls back to Groq and says so', () async {
      final id = await meeting();
      final (groq, _, after) = await run(
        id: id,
        geminiReply: (_) => const AiTransientException('429', statusCode: 429),
      );

      expect(groq.calls.single.model, kGroqNotesModel);
      expect(groq.calls.single.system, contains('výpisky'));
      final row = (await db.meetingNotesDao.forMeeting(id))!;
      expect(row.model, kGroqNotesModel);
      expect(row.content, '- Groq výpisky');
      expect(after, ['- Groq výpisky']);
    });

    test('without a key Groq gets the blocks capped', () async {
      final id = await meeting();
      final big = LessonNotesInput(
        subjectName: 'Čeština',
        photos: [for (var i = 0; i < 40; i++) 'fotka $i ${'f' * 500}'],
      );
      final (groq, gemini, _) = await run(id: id, key: false, lesson: big);
      expect(gemini.calls, isEmpty);
      expect(groq.calls.single.user, contains('Dnes Babička.'));
      expect(
        groq.calls.single.user.length,
        lessThan(kNotesExtrasGroqChars + 500),
      );
    });

    test(
      'a meeting without lesson material keeps the meeting prompt',
      () async {
        final id = await meeting();
        final (groq, gemini, after) = await run(id: id, lesson: null);
        expect(gemini.calls, isEmpty);
        expect(groq.calls.single.user, 'Dnes Babička.');
        expect(groq.calls.single.system, isNot(contains('výpisky')));
        expect(after, isEmpty);
      },
    );
  });

  test('notesInput gathers context, photos and Q&A in lesson order', () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final babicka = await db.subjectsDao.createCard(
      subjectId: cz,
      title: 'Babička',
    );
    await db.subjectsDao.createCard(subjectId: cz, title: 'Máj');
    final id = await meeting(subjectId: cz, segments: ['a', 'b', 'c']);
    await db.subjectsDao.pinCards(id, [babicka]);
    final segments = await db.transcriptSegmentsDao.segmentsForMeeting(id);

    final chat = db.chatMessagesDao;
    await chat.addUserMessage(
      meetingId: id,
      text: 'Čteme Viktorku',
      intent: ChatIntent.context,
      atMs: 1000,
    );
    final q = await chat.addUserMessage(
      meetingId: id,
      text: 'Kdo byl Proško?',
      intent: ChatIntent.question,
      atMs: 25000,
    );
    final r = await chat.addPendingReply(
      meetingId: id,
      replyTo: q,
      atMs: 25000,
    );
    await chat.completeReply(r, short: 'Myslivec.', detail: 'Z Babičky.');
    final unanswered = await chat.addUserMessage(
      meetingId: id,
      text: 'Bez odpovědi?',
      intent: ChatIntent.question,
      atMs: 26000,
    );
    await chat.addPendingReply(meetingId: id, replyTo: unanswered, atMs: 26000);
    final photo = await chat.addPhotoMessage(
      meetingId: id,
      imagePath: 'p.jpg',
      atMs: 2000,
    );
    await chat.completePhoto(photo, text: 'Realismus', description: 'Tabule');
    await chat.addPhotoMessage(meetingId: id, imagePath: 'q.jpg', atMs: 3000);

    await db
        .into(db.answerCards)
        .insert(
          AnswerCardsCompanion.insert(
            meetingId: id,
            segmentId: segments[1].id,
            question: 'Jaký je to žánr?',
            answer: 'Povídka.',
            createdAt: DateTime(2026, 9, 16),
          ),
        );

    final input = (await LessonContextSource(db).notesInput(id))!;
    expect(input.subjectName, 'Čeština');
    expect(input.cardTitles, ['Babička']);
    expect(input.context, ['Čteme Viktorku']);
    expect(input.photos, ['Tabule\nRealismus']);
    expect(input.questions.map((x) => x.question), [
      'Jaký je to žánr?',
      'Kdo byl Proško?',
    ]);
    expect(input.questions.last.answer, 'Myslivec. Z Babičky.');

    final plain = await meeting();
    expect(await LessonContextSource(db).notesInput(plain), isNull);
  });

  test(
    'a starred moment brings the transcript around it into výpisky',
    () async {
      final cz = await db.savedNotesDao.createFolder('Čeština');
      // Segments at 0–10 s, 10–20 s, … 50–60 s.
      final id = await meeting(
        subjectId: cz,
        segments: ['s0', 's1', 's2', 's3', 's4', 's5'],
      );
      await db.chatMessagesDao.addImportant(
        meetingId: id,
        atMs: 45000,
        note: ' v testu ',
      );
      await db.chatMessagesDao.addImportant(meetingId: id, atMs: 0);

      final input = (await LessonContextSource(db).notesInput(id))!;
      expect(input.important, hasLength(2));
      expect(input.important.last.excerpt, 's1 s2 s3 s4 s5');
      expect(input.important.first.excerpt, 's0 s1 s2');
      expect(input.context, isEmpty);

      final blocks = lessonNotesBlocks(input);
      expect(blocks, contains('Student označil jako důležité:'));
      expect(blocks, contains('- Poznámka: v testu\n  Řečeno: s1 s2 s3 s4 s5'));
      expect(blocks, contains('- Řečeno: s0 s1 s2'));
      expect(
        lessonNotesPrompt(NotesDepth.brief),
        contains('Every starred moment must appear'),
      );
    },
  );
}
