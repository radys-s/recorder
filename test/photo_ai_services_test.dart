import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/answer_source.dart';
import 'package:recorder/ai/board_photo_service.dart';
import 'package:recorder/ai/card_lookup_service.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/photo_text_service.dart';
import 'package:recorder/ai/web_answer_service.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/photo_picker.dart';
import 'package:recorder/features/meeting_detail/lesson_photos.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/subjects_dao.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/features/meeting_detail/widgets/chat_message_tile.dart';

class _FakeKeyStore implements ApiKeyStore {
  @override
  Future<String?> read() async => 'AIza_test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records each call; replies with [reply] (a String, a GeminiCompletion, or
/// an exception to throw).
class _FakeGemini extends GeminiProvider {
  _FakeGemini(this.reply) : super(_FakeKeyStore());

  Object reply;
  final calls = <({
    List<LlmMessage> messages,
    List<LlmImage> images,
    bool search,
    bool jsonMode,
  })>[];

  @override
  Future<GeminiCompletion> generate({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    bool search = false,
    bool jsonMode = false,
    int? maxTokens,
    Duration? timeout,
  }) async {
    calls.add((
      messages: messages,
      images: images,
      search: search,
      jsonMode: jsonMode,
    ));
    final r = reply;
    if (r is Exception) throw r;
    if (r is GeminiCompletion) return r;
    return GeminiCompletion(content: r as String);
  }
}

class _FakeWeb implements WebAnswerService {
  _FakeWeb(this.answer);

  final WebAnswer? answer;
  final queries = <String>[];

  @override
  Future<WebAnswer?> lookUp(String question) async {
    queries.add(question);
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _all(List<LlmMessage> messages) =>
    messages.map((m) => m.content).join('\n');

void main() {
  final page = LlmImage(Uint8List.fromList([1, 2, 3]));

  group('PhotoTextService.transcribePages', () {
    test('sends every page and returns clean text', () async {
      final gemini = _FakeGemini('```\nPrvní odstavec.   \n\n\n\nDruhý.\n```');
      final text =
          await PhotoTextService(gemini).transcribePages([page, page]);
      expect(text, 'První odstavec.\n\nDruhý.');
      expect(gemini.calls.single.images, hasLength(2));
      expect(gemini.calls.single.search, isFalse);
    });

    test('a page with no text is a Czech permanent failure', () async {
      for (final reply in ['NO_TEXT', '  ']) {
        await expectLater(
          PhotoTextService(_FakeGemini(reply)).transcribePages([page]),
          throwsA(isA<AiPermanentException>()
              .having((e) => e.message, 'message', contains('nenašel'))),
        );
      }
    });
  });

  group('board reading', () {
    test('parseBoardReading', () {
      final r = parseBoardReading(
          'Tady: {"text": " a² + b² = c² ", "description": "Pravoúhlý trojúhelník."}')!;
      expect(r.text, 'a² + b² = c²');
      expect(r.description, 'Pravoúhlý trojúhelník.');
      expect(parseBoardReading('{"text": "", "description": ""}'), isNull);
      expect(parseBoardReading('nic'), isNull);
      expect(parseBoardReading('{"text": 3, "description": "Graf"}')!.text, '');
    });

    test('readBoard asks in JSON mode with the subject', () async {
      final gemini = _FakeGemini('{"text": "Máj", "description": "Nadpis."}');
      final r = await PhotoTextService(gemini)
          .readBoard(page, subjectName: 'Čeština');
      expect(r.text, 'Máj');
      expect(gemini.calls.single.jsonMode, isTrue);
      expect(_all(gemini.calls.single.messages), contains('Čeština'));
      // Slides keep their structure.
      expect(_all(gemini.calls.single.messages), contains('presentation slide'));
      expect(_all(gemini.calls.single.messages), contains(' | '));
    });
  });

  group('addLessonPhotos', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    PickedPhoto photo(int n) => PickedPhoto(
          bytes: Uint8List.fromList([n]),
          mimeType: 'image/jpeg',
          extension: '.jpg',
        );

    test('each photo is its own pending message, in picking order', () async {
      final meetingId = await db.into(db.meetings).insert(
          MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026)));
      final added = await addLessonPhotos(
        photos: [photo(1), photo(2), photo(3)],
        meetingId: meetingId,
        atMs: 5000,
        chat: db.chatMessagesDao,
        store: (p) async {
          if (p.bytes.first == 2) throw const FileSystemException('disk');
          return 'photos/meeting_$meetingId/p${p.bytes.first}.jpg';
        },
      );

      expect(added.ids, hasLength(2));
      expect(added.failed, 1);
      final rows = await db.chatMessagesDao.messages(meetingId);
      expect(rows.map((m) => m.imagePath), [
        'photos/meeting_$meetingId/p1.jpg',
        'photos/meeting_$meetingId/p3.jpg',
      ]);
      expect(rows.every((m) => m.status == ChatStatus.pending), isTrue);
      expect(rows.every((m) => m.intent == ChatIntent.photo), isTrue);
      expect(rows.every((m) => m.atMs == 5000), isTrue);
    });
  });

  test('geminiFailureText', () {
    expect(
      geminiFailureText(
          const AiPermanentException('Chybí Gemini klíč. Přidej ho v Nastavení.')),
      startsWith('Chybí Gemini klíč'),
    );
    expect(geminiFailureText(const AiTransientException('429', statusCode: 429)),
        contains('limit'));
    expect(geminiFailureText(const AiPermanentException('x', statusCode: 403)),
        contains('403'));
    expect(geminiFailureText(StateError('x')), isNotEmpty);
  });

  group('BoardPhotoService', () {
    late AppDatabase db;
    late int meeting;

    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      meeting = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026, 9, 15)),
      );
    });
    tearDown(() => db.close());

    BoardPhotoService service(_FakeGemini gemini, {bool missingFile = false}) =>
        BoardPhotoService(
          db.chatMessagesDao,
          PhotoTextService(gemini),
          readBytes: (path) async {
            if (missingFile) throw PathNotFoundException(path, const OSError());
            return Uint8List.fromList([9]);
          },
          subjectName: (_) async => 'Fyzika',
        );

    Future<int> photo(String path) => db.chatMessagesDao
        .addPhotoMessage(meetingId: meeting, imagePath: path, atMs: 0);

    test('reads the photo into the message', () async {
      final gemini =
          _FakeGemini('{"text": "F = m·a", "description": "Newtonův zákon."}');
      final id = await photo('photos/meeting_1/p.png');

      expect(await service(gemini).read(id), isTrue);

      final row = (await db.chatMessagesDao.message(id))!;
      expect(row.status, ChatStatus.ready);
      expect(row.body, 'F = m·a');
      expect(row.short, 'Newtonův zákon.');
      expect(gemini.calls.single.images.single.mimeType, 'image/png');
      expect(_all(gemini.calls.single.messages), contains('Fyzika'));
    });

    test('a failed read is stored with a reason, and a retry recovers',
        () async {
      final gemini = _FakeGemini(const AiTransientException('503'));
      final id = await photo('photos/meeting_1/p.jpg');

      expect(await service(gemini).read(id), isFalse);
      var row = (await db.chatMessagesDao.message(id))!;
      expect(row.status, ChatStatus.failed);
      expect(row.detail, contains('neodpovídá'));

      gemini.reply = '{"text": "OK", "description": ""}';
      expect(await service(gemini).read(id), isTrue);
      row = (await db.chatMessagesDao.message(id))!;
      expect(row.status, ChatStatus.ready);
      expect(row.detail, isNull);
    });

    test('a missing file says so and makes no request', () async {
      final gemini = _FakeGemini('{"text": "x", "description": ""}');
      final id = await photo('photos/meeting_1/p.jpg');

      expect(await service(gemini, missingFile: true).read(id), isFalse);
      expect(gemini.calls, isEmpty);
      expect((await db.chatMessagesDao.message(id))!.detail, 'Fotka se nenašla.');
    });

    test('ignores anything that is not a photo message', () async {
      final gemini = _FakeGemini('{}');
      final id = await db.chatMessagesDao.addUserMessage(
        meetingId: meeting,
        text: 'Čteme Máj',
        intent: ChatIntent.context,
        atMs: 0,
      );
      expect(await service(gemini).read(id), isFalse);
      expect(await service(gemini).read(9999), isFalse);
      expect(gemini.calls, isEmpty);
    });
  });

  group('CardLookupService', () {
    final wiki = AnswerSource(
        title: 'Wikipedie', url: Uri.parse('https://cs.wikipedia.org/wiki/Máj'));

    CardLookupService service(
      _FakeGemini gemini,
      _FakeWeb web, {
      Future<bool> Function()? hasKey,
    }) =>
        CardLookupService(
          gemini: gemini,
          hasGeminiKey: hasKey ?? () async => true,
          web: web,
        );

    test('with a key: Gemini with search, links stripped, sources kept',
        () async {
      final gemini = _FakeGemini(GeminiCompletion(
        content: 'Autor:\n- Karel Hynek Mácha\n\nhttps://cs.wikipedia.org/wiki/Máj',
        sources: [wiki],
      ));
      final web = _FakeWeb(null);
      final found = await service(gemini, web)
          .lookUp(' Máj ', subjectName: 'Čeština');

      expect(found.content, 'Autor:\n- Karel Hynek Mácha');
      expect(found.sources, [wiki]);
      expect(found.viaGemini, isTrue);
      expect(gemini.calls.single.search, isTrue);
      final prompt = _all(gemini.calls.single.messages);
      expect(prompt, contains('Topic: Máj'));
      expect(prompt, contains('Čeština'));
      expect(prompt, contains('Literární žánr:'));
      expect(web.queries, isEmpty);
    });

    test('without a key: the Groq web answer, marked as such', () async {
      final gemini = _FakeGemini('nepoužito');
      final web = _FakeWeb(WebAnswer(answer: 'Máj je lyrickoepická báseň.', sources: [wiki]));
      final found = await service(gemini, web, hasKey: () async => false)
          .lookUp('Máj', subjectName: 'Čeština');

      expect(found.viaGemini, isFalse);
      expect(found.content, 'Máj je lyrickoepická báseň.');
      expect(web.queries, ['Máj (Čeština)']);
      expect(gemini.calls, isEmpty);
    });

    test('a key store that throws counts as no key', () async {
      final web = _FakeWeb(WebAnswer(answer: 'x', sources: const []));
      await service(_FakeGemini('y'), web, hasKey: () async => throw StateError('keychain'))
          .lookUp('Máj');
      expect(web.queries, ['Máj']);
    });

    test('nothing found is a Czech transient failure', () async {
      await expectLater(
        service(_FakeGemini('y'), _FakeWeb(null), hasKey: () async => false)
            .lookUp('Máj'),
        throwsA(isA<AiTransientException>()
            .having((e) => geminiFailureText(e), 'text', startsWith('Dohledání'))),
      );
      await expectLater(
        service(_FakeGemini('   '), _FakeWeb(null)).lookUp('Máj'),
        throwsA(isA<AiPermanentException>()),
      );
    });

    test('a blank query is refused before any request', () {
      expect(() => service(_FakeGemini('y'), _FakeWeb(null)).lookUp('  '),
          throwsArgumentError);
    });

    test('mergeCardSources de-duplicates by site and caps', () {
      AnswerSource s(String host, [String path = '']) =>
          AnswerSource(title: host, url: Uri.parse('https://$host/$path'));
      final merged = mergeCardSources(
        [s('cs.wikipedia.org', 'a'), s('www.cesky-jazyk.cz')],
        [s('cs.wikipedia.org', 'b'), s('cesky-jazyk.cz'), s('rozbor-dila.cz')],
      );
      expect([for (final m in merged) m.domain],
          ['cs.wikipedia.org', 'cesky-jazyk.cz', 'rozbor-dila.cz']);
      expect(merged.first.url.path, '/a');

      final many = mergeCardSources(
          [], [for (var i = 0; i < 20; i++) s('site$i.cz')]);
      expect(many, hasLength(kMaxCardSources));
    });
  });

  test('boardCardTitle', () {
    expect(boardCardTitle('Nákres buňky s mitochondrií. Pod ním popisky.'),
        'Nákres buňky s mitochondrií');
    expect(boardCardTitle('Vzorec pro obsah kruhu.'), 'Vzorec pro obsah kruhu');
    expect(boardCardTitle('  '), 'Z tabule');
    final long = boardCardTitle('slovo ' * 60);
    expect(long.length, lessThanOrEqualTo(SubjectsDao.maxCardTitleLength));
    expect(long.endsWith(' '), isFalse);
  });
}
