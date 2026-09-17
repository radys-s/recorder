import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/answer_source.dart';
import 'package:recorder/ai/course_profile.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/ai/syllabus_import_service.dart';
import 'package:recorder/core/gemini_failure.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';
import 'package:recorder/data/secure/api_key_store.dart';

class _FakeKeyStore implements ApiKeyStore {
  @override
  Future<String?> read() async => 'AIza_test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGemini extends GeminiProvider {
  _FakeGemini(this.reply) : super(_FakeKeyStore());

  final Object reply; // GeminiCompletion, or an exception to throw
  final searches = <bool>[];
  final prompts = <String>[];
  var imageCount = 0;

  @override
  Future<GeminiCompletion> generate({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    bool search = false,
    bool jsonMode = false,
    int? maxTokens,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    searches.add(search);
    prompts.add(messages.last.content);
    imageCount = images.length;
    final r = reply;
    if (r is Exception) throw r;
    return r as GeminiCompletion;
  }
}

class _FakeLlm extends LlmProvider {
  _FakeLlm(this.reply);

  final String reply;
  final prompts = <String>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    prompts.add(messages.last.content);
    return LlmCompletion(content: reply);
  }
}

const _plan =
    '{"topics":[{"title":"Model OSI","terms":["OSI"],"month_from":9},'
    '{"title":"Směrování","terms":"RIP, OSPF","month_from":11}]}';

SyllabusImportService _service(
  _FakeGemini gemini,
  _FakeLlm llm, {
  bool key = true,
}) => SyllabusImportService(
  gemini: gemini,
  llm: llm,
  hasGeminiKey: () async => key,
);

void main() {
  group('SyllabusImportService', () {
    test('pasted text goes to Gemini with the course line', () async {
      final gemini = _FakeGemini(const GeminiCompletion(content: _plan));
      final llm = _FakeLlm('');
      final result = await _service(
        gemini,
        llm,
      ).fromText('1. OSI\n2. Směrování', course: 'Počítačové sítě, 3. ročník');
      expect(result.topics.map((t) => t.title), ['Model OSI', 'Směrování']);
      expect(result.estimated, isFalse);
      expect(gemini.prompts.single, contains('Počítačové sítě, 3. ročník'));
      expect(llm.prompts, isEmpty);
    });

    test('busy Gemini falls back to the router', () async {
      final gemini = _FakeGemini(
        const AiTransientException(
          'busy',
          statusCode: 503,
          kind: GeminiErrorKind.overloaded,
        ),
      );
      final llm = _FakeLlm(_plan);
      final result = await _service(gemini, llm).fromText('x', course: 'c');
      expect(result.topics, hasLength(2));
      expect(llm.prompts, hasLength(1));
    });

    test('a wrong Gemini key is reported, not hidden', () async {
      final gemini = _FakeGemini(
        const AiPermanentException(
          'bad',
          statusCode: 400,
          kind: GeminiErrorKind.badKey,
        ),
      );
      await expectLater(
        _service(gemini, _FakeLlm(_plan)).fromText('x', course: 'c'),
        throwsA(isA<AiPermanentException>()),
      );
    });

    test('no key uses the router only, text cut to its limit', () async {
      final gemini = _FakeGemini(const GeminiCompletion(content: _plan));
      final llm = _FakeLlm(_plan);
      await _service(
        gemini,
        llm,
        key: false,
      ).fromText('a' * (kSyllabusTextRouterChars + 500), course: 'c');
      expect(gemini.prompts, isEmpty);
      expect(
        llm.prompts.single.length,
        lessThan(kSyllabusTextRouterChars + 100),
      );
    });

    test('nothing readable is a Czech error', () async {
      final gemini = _FakeGemini(const GeminiCompletion(content: '{}'));
      await expectLater(
        _service(gemini, _FakeLlm('nic')).fromText('x', course: 'c'),
        throwsA(
          isA<AiPermanentException>().having(
            (e) => e.message,
            'message',
            contains('témata'),
          ),
        ),
      );
    });

    test('photos go to Gemini vision', () async {
      final gemini = _FakeGemini(const GeminiCompletion(content: _plan));
      final image = LlmImage(Uint8List(3), mimeType: 'image/jpeg');
      final result = await _service(
        gemini,
        _FakeLlm(''),
      ).fromImages([image, image], course: 'c');
      expect(result.topics, hasLength(2));
      expect(gemini.imageCount, 2);
    });

    test('estimate searches and keeps sources, flagged', () async {
      final source = AnswerSource(
        title: 'skola.cz',
        url: Uri.parse('https://skola.cz/svp'),
      );
      final gemini = _FakeGemini(
        GeminiCompletion(content: _plan, sources: [source]),
      );
      final result = await _service(
        gemini,
        _FakeLlm(''),
      ).estimate(course: 'Počítačové sítě, SOŠ, 3. ročník');
      expect(gemini.searches.single, isTrue);
      expect(result.estimated, isTrue);
      expect(result.sources.single.url.host, 'skola.cz');
    });

    test('estimate without topics from search asks the router', () async {
      final gemini = _FakeGemini(const GeminiCompletion(content: 'Nevím.'));
      final llm = _FakeLlm(_plan);
      final result = await _service(gemini, llm).estimate(course: 'c');
      expect(result.topics, hasLength(2));
      expect(result.estimated, isTrue);
      expect(result.sources, isEmpty);
    });
  });

  group('courseLine', () {
    Subject subject({String? fullName, String? level}) => Subject(
      id: 1,
      name: 'PS',
      createdAt: DateTime(2026),
      colorIndex: 0,
      sortOrder: 0,
      fullName: fullName,
      levelOverride: level,
    );

    test('full profile', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.preferencesDao.setStudyProfile(
        schoolName: ' SPŠE Ječná ',
        schoolType: SchoolType.secondaryTechnical,
        studyField: 'IT',
        studyYear: 3,
      );
      final prefs = await db.preferencesDao.current();
      expect(
        courseLine(subject(fullName: 'Počítačové sítě'), prefs),
        'Počítačové sítě, SOŠ, SPŠE Ječná, obor IT, 3. ročník',
      );
      expect(
        courseLine(subject(level: 'maturitní seminář'), prefs),
        'PS, SOŠ, SPŠE Ječná, obor IT, maturitní seminář',
      );
    });

    test('nothing set gives the subject name', () {
      expect(courseLine(subject(fullName: '  '), null), 'PS');
    });
  });

  group('SubjectsDao syllabus', () {
    late AppDatabase db;
    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('replace, pick for a lesson, delete and cascade', () async {
      final dao = db.subjectsDao;
      final ps = await db.savedNotesDao.createFolder('PS');
      await dao.replaceTopics(ps, [
        const SyllabusTopicDraft(title: 'OSI', terms: ['OSI', 'TCP/IP']),
        const SyllabusTopicDraft(title: '  '),
        const SyllabusTopicDraft(
          title: 'Směrování',
          monthFrom: 11,
          monthTo: 12,
        ),
      ], SyllabusSource.ai);
      var topics = await dao.topics(ps);
      expect(topics.map((t) => (t.ord, t.title)), [
        (0, 'OSI'),
        (1, 'Směrování'),
      ]);
      expect(topics.first.terms, 'OSI, TCP/IP');
      expect(topics.first.source, SyllabusSource.ai);
      expect(topics.last.monthTo, 12);

      final lesson = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: DateTime(2026, 11, 3),
          subjectId: Value(ps),
        ),
      );
      await dao.setMeetingTopic(lesson, topics.last.id);
      Future<int?> picked() async => (await (db.select(
        db.meetings,
      )..where((t) => t.id.equals(lesson))).getSingle()).topicId;
      expect(await picked(), topics.last.id);

      await dao.deleteTopic(topics.last.id);
      expect(await picked(), isNull);

      await dao.setMeetingTopic(lesson, topics.first.id);
      await dao.replaceTopics(ps, const [
        SyllabusTopicDraft(title: 'Nový'),
      ], SyllabusSource.pasted);
      expect(await picked(), isNull);
      topics = await dao.topics(ps);
      expect(topics.single.title, 'Nový');

      await dao.setSubjectProfile(
        ps,
        fullName: 'Počítačové sítě ',
        levelOverride: ' ',
      );
      final subject = await dao.subject(ps);
      expect(subject!.fullName, 'Počítačové sítě');
      expect(subject.levelOverride, isNull);

      await dao.deleteSubject(ps);
      expect(await db.select(db.syllabusTopics).get(), isEmpty);
    });

    test('study year outside 1-10 is dropped', () async {
      await db.preferencesDao.setStudyProfile(studyYear: 42, studyField: ' ');
      final prefs = await db.preferencesDao.current();
      expect(prefs.studyYear, isNull);
      expect(prefs.studyField, isNull);
    });
  });
}
