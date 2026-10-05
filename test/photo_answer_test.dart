import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/board_photo_service.dart';
import 'package:recorder/ai/chat_answer_service.dart';
import 'package:recorder/ai/context_builder.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/lesson_context_source.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/photo_text_service.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/secure/api_key_store.dart';

/// A photo with questions on it ends in an answer under the photo — and
/// whatever happens to that answer, the text read off the photo stays.
class _KeyStore implements ApiKeyStore {
  @override
  Future<String?> read() async => 'AIza_test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ocr extends GeminiProvider {
  _Ocr(this.reply) : super(_KeyStore());

  final String reply;

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
  }) async => GeminiCompletion(content: reply);
}

class _Llm extends LlmProvider {
  _Llm(this.behaviour);

  Object behaviour;
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
    prompts.add(messages.map((m) => m.content).join('\n'));
    final b = behaviour;
    if (b is String) return LlmCompletion(content: b);
    if (b is Completer<LlmCompletion>) return b.future;
    throw b;
  }
}

class _NoMaterial implements LessonContextSource {
  @override
  Future<LessonMaterial> load(int meetingId) async => const LessonMaterial();

  @override
  Future<void> markUsed(int cardId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _answer =
    '{"short": "Proško", "detail": "1) Proško.\\n2) Idyla.", "basis": "knowledge"}';

String _ocr(String text, [List<String> questions = const []]) =>
    '{"text": ${_json(text)}, "description": "Pracovní list", '
    '"questions": [${questions.map(_json).join(',')}]}';

String _json(String s) =>
    '"${s.replaceAll('\n', '\\n').replaceAll('"', '\\"')}"';

void main() {
  late AppDatabase db;
  late int meeting;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    meeting = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: 'Hodina',
        createdAt: DateTime(2026, 10, 5),
      ),
    );
  });
  tearDown(() => db.close());

  ChatAnswerService answers(_Llm llm, {Duration? watchdog}) =>
      ChatAnswerService(
        llm,
        db.chatMessagesDao,
        db.transcriptSegmentsDao,
        _NoMaterial(),
        watchdog: watchdog ?? const Duration(seconds: 5),
      );

  BoardPhotoService photos(String ocrReply, ChatAnswerService answerService) =>
      BoardPhotoService(
        db.chatMessagesDao,
        PhotoTextService(_Ocr(ocrReply)),
        readBytes: (_) async => Uint8List.fromList([1]),
        answer: (id, questions) =>
            answerService.askAboutPhoto(id, questions: questions),
      );

  Future<int> photo() => db.chatMessagesDao.addPhotoMessage(
    meetingId: meeting,
    imagePath: 'photos/meeting_1/p.jpg',
    atMs: 0,
  );

  test('questions the model found are answered under the photo', () async {
    final llm = _Llm(_answer);
    final id = await photo();
    final ok = await photos(
      _ocr('1) Kdo byl Proško?\n2) Vysvětli pojem idyla.', [
        'Kdo byl Proško?',
        'Vysvětli pojem idyla.',
      ]),
      answers(llm),
    ).read(id);

    expect(ok, isTrue);
    final reply = (await db.chatMessagesDao.replyTo(id))!;
    expect(reply.status, ChatStatus.ready);
    expect(reply.replyTo, id);
    expect(reply.short, 'Proško');
    expect(llm.prompts.single, contains('1) Kdo byl Proško?'));
    expect(llm.prompts.single, contains('2) Vysvětli pojem idyla.'));
    expect(llm.prompts.single, contains('photographed'));
  });

  test(
    'with no questions from the model the text is searched locally',
    () async {
      final llm = _Llm(_answer);
      final id = await photo();
      await photos(
        _ocr('Pracovní list\n1) Kdo byl Proško?'),
        answers(llm),
      ).read(id);

      expect((await db.chatMessagesDao.replyTo(id))!.status, ChatStatus.ready);
      expect(llm.prompts.single, contains('1) Kdo byl Proško?'));
    },
  );

  test('a photo with no questions gets no reply and no request', () async {
    final llm = _Llm(_answer);
    final id = await photo();
    await photos(_ocr('Realismus vznikl v 19. století'), answers(llm)).read(id);

    expect(await db.chatMessagesDao.replyTo(id), isNull);
    expect(llm.prompts, isEmpty);
    expect((await db.chatMessagesDao.message(id))!.status, ChatStatus.ready);
  });

  test('a failed answer never costs the text read off the photo', () async {
    final llm = _Llm(const AiTransientException('429', source: 'Groq'));
    final id = await photo();
    final ok = await photos(
      _ocr('1) Kdo byl Proško?', ['Kdo byl Proško?']),
      answers(llm),
    ).read(id);

    expect(ok, isTrue);
    final row = (await db.chatMessagesDao.message(id))!;
    expect(row.status, ChatStatus.ready);
    expect(row.body, '1) Kdo byl Proško?');
    final reply = (await db.chatMessagesDao.replyTo(id))!;
    expect(reply.status, ChatStatus.failed);
    expect(reply.body, contains('znovu'));
  });

  test(
    'a provider that hangs ends the reply in a failure, not pending',
    () async {
      final llm = _Llm(Completer<LlmCompletion>());
      final id = await photo();
      final service = answers(llm, watchdog: const Duration(milliseconds: 50));
      await photos(_ocr('1) Co je idyla?', ['Co je idyla?']), service).read(id);
      final reply = (await db.chatMessagesDao.replyTo(id))!;
      expect(reply.status, ChatStatus.failed);
      expect(reply.body, contains('dlouho'));
    },
  );

  test(
    'retrying the failed reply answers the photo, in the same row',
    () async {
      final llm = _Llm(const AiTransientException('429'));
      final service = answers(llm);
      final id = await photo();
      await photos(_ocr('1) Co je idyla?', ['Co je idyla?']), service).read(id);
      final failed = (await db.chatMessagesDao.replyTo(id))!;

      llm.behaviour = _answer;
      // The bubble's retry calls ask() with the id the reply points at.
      await service.ask(id);

      final retried = (await db.chatMessagesDao.replyTo(id))!;
      expect(retried.id, failed.id);
      expect(retried.status, ChatStatus.ready);
      expect(llm.prompts.last, contains('photographed'));
      expect(llm.prompts.last, contains('1) Co je idyla?'));
    },
  );

  test('the manual button answers a photo that has none yet', () async {
    final llm = _Llm(_answer);
    final service = answers(llm);
    final id = await photo();
    final board = photos(_ocr('Realismus a naturalismus'), service);
    await board.read(id);
    expect(await db.chatMessagesDao.replyTo(id), isNull);

    await board.answerQuestions(id);

    expect((await db.chatMessagesDao.replyTo(id))!.status, ChatStatus.ready);
    // No questions found locally: the whole text goes to the model.
    expect(llm.prompts.single, contains('Realismus a naturalismus'));
  });

  test('the manual button ignores an unread or failed photo', () async {
    final llm = _Llm(_answer);
    final board = photos(_ocr('x'), answers(llm));
    final id = await photo();
    await board.answerQuestions(id);
    await board.answerQuestions(9999);
    expect(llm.prompts, isEmpty);
    expect(await db.chatMessagesDao.replyTo(id), isNull);
  });
}
