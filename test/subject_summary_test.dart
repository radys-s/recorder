import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/course_overview.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/subject_summary_service.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/gemini_failure.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';

class _Llm extends LlmProvider {
  _Llm([this.reply = 'Co jsme probrali:\n- OSI a TCP/IP', this.error]);
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
    if (error != null) throw error!;
    return LlmCompletion(content: reply);
  }
}

final _today = DateTime(2026, 12, 10);

void main() {
  late AppDatabase db;
  late int subject;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    subject = await db.savedNotesDao.createFolder('Počítačové sítě');
    await db.subjectsDao.replaceTopics(subject, const [
      SyllabusTopicDraft(title: 'TCP/IP', terms: ['TCP', 'IP'], monthFrom: 10),
      SyllabusTopicDraft(title: 'Adresace', monthFrom: 11),
      SyllabusTopicDraft(title: 'VLAN', monthFrom: 12),
    ], SyllabusSource.pasted);
  });
  tearDown(() => db.close());

  Future<int> lesson(DateTime at, {String? notes, int? subjectId}) async {
    final id = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: 'Hodina',
        createdAt: at,
        subjectId: Value(subjectId ?? subject),
      ),
    );
    if (notes != null) {
      await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
      await db.meetingNotesDao.markReady(id, notes);
    }
    return id;
  }

  SubjectSummaryService service(
    _Llm router, {
    _Llm? gemini,
    bool hasKey = true,
  }) => SubjectSummaryService(
    db,
    llm: router,
    gemini: gemini,
    hasGeminiKey: () async => hasKey,
    now: () => _today,
  );

  test('the plan and the výpisky go in, the summary lands in the subject',
      () async {
    await lesson(DateTime(2026, 12, 2), notes: 'VLAN rozděluje síť.');
    await lesson(DateTime(2026, 10, 6), notes: 'TCP zaručuje doručení.');
    await lesson(DateTime(2026, 10, 20)); // no výpisky
    await lesson(
      DateTime(2026, 10, 7),
      notes: 'Jiný předmět',
      subjectId: await db.savedNotesDao.createFolder('Čeština'),
    );
    final router = _Llm('  Co jsme probrali:\n- TCP a VLAN  ');

    final result = await service(router).summarize(subject);

    expect(result.error, isNull);
    expect(router.models, [kGroqNotesModel]);
    final input = router.users.single;
    expect(input, startsWith('Kurz: Počítačové sítě\nDnes: 10. 12. 2026'));
    expect(input, contains('1. TCP/IP — Probráno (2× hodina)'));
    expect(input, contains('   Pojmy: TCP, IP'));
    expect(input, contains('2. Adresace — Chybí záznam\n'));
    expect(input, contains('3. VLAN — Probráno (1× hodina)'));
    expect(input, contains('=== Hodina 6. 10. 2026 · téma: TCP/IP ===\n'
        'TCP zaručuje doručení.'));
    expect(
      input.indexOf('6. 10. 2026'),
      lessThan(input.indexOf('2. 12. 2026')),
    );
    expect(input, isNot(contains('Jiný předmět')));
    expect(input, isNot(contains('20. 10. 2026')));

    final note = (await db.select(db.savedNotes).get()).single;
    expect(result.noteId, note.id);
    expect(note.title, 'Shrnutí předmětu – Počítačové sítě (10. 12. 2026)');
    expect(note.folderId, subject);
    expect(note.content, 'Co jsme probrali:\n- TCP a VLAN');
  });

  test('Gemini writes it when there is a key', () async {
    await lesson(DateTime(2026, 10, 6), notes: 'TCP');
    final router = _Llm();
    final gemini = _Llm('Z Gemini');

    final result = await service(router, gemini: gemini).summarize(subject);

    expect(result.noteId, isNotNull);
    expect(gemini.models, [kGeminiModel]);
    expect(router.models, isEmpty);
    expect(
      (await db.select(db.savedNotes).getSingle()).content,
      'Z Gemini',
    );
  });

  test('no key means no Gemini call', () async {
    await lesson(DateTime(2026, 10, 6), notes: 'TCP');
    final router = _Llm();
    final gemini = _Llm();

    await service(router, gemini: gemini, hasKey: false).summarize(subject);

    expect(gemini.models, isEmpty);
    expect(router.models, [kGroqNotesModel]);
  });

  test('an overloaded or refusing Gemini hands over to the router', () async {
    await lesson(DateTime(2026, 10, 6), notes: 'TCP');
    for (final error in [
      const AiTransientException('busy', kind: GeminiErrorKind.overloaded),
      const AiPermanentException('no model', kind: GeminiErrorKind.modelMissing),
    ]) {
      final router = _Llm();
      final result = await service(router, gemini: _Llm('', error))
          .summarize(subject);
      expect(result.noteId, isNotNull, reason: '$error');
      expect(router.models, [kGroqNotesModel]);
    }
  });

  test('an empty Gemini reply also hands over', () async {
    await lesson(DateTime(2026, 10, 6), notes: 'TCP');
    final router = _Llm();
    await service(router, gemini: _Llm('  ')).summarize(subject);
    expect(router.models, [kGroqNotesModel]);
  });

  test('a bad Gemini key is said, not hidden behind the router', () async {
    await lesson(DateTime(2026, 10, 6), notes: 'TCP');
    final router = _Llm();
    final gemini = _Llm(
      '',
      const AiPermanentException('bad', statusCode: 400,
          kind: GeminiErrorKind.badKey),
    );

    final result = await service(router, gemini: gemini).summarize(subject);

    expect(result.noteId, isNull);
    expect(result.error, contains('Gemini klíč neprošel'));
    expect(router.models, isEmpty);
    expect(await db.select(db.savedNotes).get(), isEmpty);
  });

  test('without výpisky nothing is asked', () async {
    await lesson(DateTime(2026, 10, 6));
    final router = _Llm();

    final result = await service(router).summarize(subject);

    expect(result.error, startsWith('Zatím tu nejsou žádné výpisky.'));
    expect(router.models, isEmpty);
  });

  test('failures come back as sentences', () async {
    await lesson(DateTime(2026, 10, 6), notes: 'TCP');

    Future<String?> failWith(Object error) async =>
        (await service(_Llm('', error)).summarize(subject)).error;

    expect(
      await failWith(const AiTransientException('429', statusCode: 429)),
      startsWith('AI služby teď neodpovídají'),
    );
    expect(
      await failWith(const AiPermanentException('No Groq API key set')),
      'Chybí AI klíč. Přidej ho v Nastavení.',
    );
    expect(
      await failWith(const AiPermanentException('x', statusCode: 403)),
      'AI požadavek odmítla (HTTP 403).',
    );
    expect(
      await failWith(StateError('boom')),
      'Shrnutí se nepodařilo. Zkus to znovu.',
    );
    expect(
      (await service(_Llm(' ')).summarize(subject)).error,
      'AI vrátila prázdné shrnutí. Zkus to znovu.',
    );
    expect(
      (await service(_Llm()).summarize(subject + 100)).error,
      'Předmět už neexistuje.',
    );
    expect(await db.select(db.savedNotes).get(), isEmpty);
  });

  group('input', () {
    test('without a plan the model is told so', () {
      final input = subjectSummaryInput(
        course: 'Dějepis',
        today: _today,
        overview: const CourseOverview([]),
        lessons: [SummaryLesson(date: DateTime(2026, 9, 3), notes: 'Pravěk')],
        budget: 1000,
      );
      expect(input, contains('Tematický plán (v pořadí výuky):\n'
          '(tematický plán není zadaný)'));
      expect(input, contains('=== Hodina 3. 9. 2026 ===\nPravěk'));
    });

    test('the výpisky share the budget evenly', () {
      final texts = ['a' * 100, 'b' * 5000, 'c' * 5000];
      final out = evenShare(texts, 3000);

      expect(out.first, texts.first);
      expect(out.fold<int>(0, (n, t) => n + t.length), lessThanOrEqualTo(3000));
      expect(out[1], endsWith('\n[…]'));
      expect(out[1].length, closeTo(out[2].length, 1));
    });

    test('a cut prefers a line break', () {
      final text = '${'x' * 60}\n${'y' * 60}';
      expect(evenShare([text], 100), ['${'x' * 60}\n[…]']);
    });

    test('whatever fits stays whole', () {
      expect(evenShare(['ab', 'cd'], 10), ['ab', 'cd']);
      expect(evenShare(['a' * 50], 3), ['']);
    });
  });
}
