import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/chat_answer_service.dart';
import 'package:recorder/ai/context_builder.dart';
import 'package:recorder/ai/lesson_context_source.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';

/// Every way a typed question can end. The rule under test: whatever happens,
/// the reply row ends `ready` or `failed` — never `pending` forever — and a
/// failure says something a student can act on.
class _Llm extends LlmProvider {
  _Llm(this.behaviour);

  /// A String is the reply, a Completer hangs, anything else is thrown.
  Object behaviour;
  int calls = 0;
  String? lastPrompt;

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
    lastPrompt = messages.map((m) => m.content).join('\n');
    final b = behaviour;
    if (b is Completer<LlmCompletion>) return b.future;
    if (b is String) return LlmCompletion(content: b);
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

class _ThrowingMaterial extends _NoMaterial {
  @override
  Future<LessonMaterial> load(int meetingId) async =>
      throw StateError('disk gone');
}

const _good = '{"short": "Myslivec", "detail": "", "basis": "knowledge"}';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ChatAnswerService service(
    _Llm llm, {
    LessonContextSource? material,
    Duration watchdog = const Duration(seconds: 5),
  }) => ChatAnswerService(
    llm,
    db.chatMessagesDao,
    db.transcriptSegmentsDao,
    material ?? _NoMaterial(),
    watchdog: watchdog,
  );

  Future<int> question([String text = 'Kdo byl Proško?']) =>
      db.chatMessagesDao.addUserMessage(
        meetingId: 1,
        text: text,
        intent: ChatIntent.question,
        atMs: 0,
      );

  Future<void> addSegments(int count, {required String word}) async {
    for (var i = 0; i < count; i++) {
      await db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: 1,
          sequence: i,
          startMs: i * 1000,
          endMs: i * 1000 + 900,
          localAudioPath: 'x$i.wav',
          content: Value('$word $i'),
          status: SegmentStatus.transcribed,
          createdAt: DateTime(2026, 10, 5),
        ),
      );
    }
  }

  test('a good answer is stored as ready', () async {
    final q = await question();
    await service(_Llm(_good)).ask(q);
    final reply = await db.chatMessagesDao.replyTo(q);
    expect(reply!.status, ChatStatus.ready);
    expect(reply.short, 'Myslivec');
  });

  test('every route cooling ends failed with a retryable message', () async {
    final q = await question();
    await service(_Llm(const AiTransientException('429', source: 'Groq')))
        .ask(q);
    final reply = await db.chatMessagesDao.replyTo(q);
    expect(reply!.status, ChatStatus.failed);
    expect(reply.body, contains('Groq'));
    expect(reply.body, contains('znovu'));
  });

  test('a refused key points at Settings', () async {
    final q = await question();
    await service(_Llm(const AiPermanentException('401', source: 'Groq')))
        .ask(q);
    final reply = await db.chatMessagesDao.replyTo(q);
    expect(reply!.status, ChatStatus.failed);
    expect(reply.body, contains('Nastavení'));
  });

  test('a reply with no JSON fails instead of hanging', () async {
    final q = await question();
    await service(_Llm('Promiň, nevím.')).ask(q);
    final reply = await db.chatMessagesDao.replyTo(q);
    expect(reply!.status, ChatStatus.failed);
  });

  test('an unexpected exception in the provider still ends the row', () async {
    final q = await question();
    await service(_Llm(StateError('boom'))).ask(q);
    final reply = await db.chatMessagesDao.replyTo(q);
    expect(reply!.status, ChatStatus.failed);
  });

  test('an exception while loading the lesson ends the row too', () async {
    final q = await question();
    await service(_Llm(_good), material: _ThrowingMaterial()).ask(q);
    final reply = await db.chatMessagesDao.replyTo(q);
    expect(reply!.status, ChatStatus.failed);
  });

  test('a provider that never answers is cut by the watchdog', () async {
    final q = await question();
    final llm = _Llm(Completer<LlmCompletion>());
    await service(llm, watchdog: const Duration(milliseconds: 80)).ask(q);
    final reply = await db.chatMessagesDao.replyTo(q);
    expect(reply!.status, ChatStatus.failed);
    expect(reply.body, contains('dlouho'));
  });

  test('an empty transcript still gets an answer', () async {
    final q = await question();
    final llm = _Llm(_good);
    await service(llm).ask(q);
    expect(llm.lastPrompt, contains('nothing transcribed yet'));
    expect((await db.chatMessagesDao.replyTo(q))!.status, ChatStatus.ready);
  });

  test('a very long transcript is cut, not refused', () async {
    await addSegments(4000, word: 'dlouhetextove');
    final q = await question();
    final llm = _Llm(_good);
    await service(llm).ask(q);
    expect((await db.chatMessagesDao.replyTo(q))!.status, ChatStatus.ready);
    // The whole transcript is ~60 000 characters; the budget cuts it.
    expect(llm.lastPrompt!.length, lessThan(30000));
  });

  test('a failed reply is retried in the same row', () async {
    final q = await question();
    final llm = _Llm(const AiTransientException('429'));
    final s = service(llm);
    await s.ask(q);
    final failed = await db.chatMessagesDao.replyTo(q);
    llm.behaviour = _good;
    await s.ask(q);
    final retried = await db.chatMessagesDao.replyTo(q);
    expect(retried!.id, failed!.id);
    expect(retried.status, ChatStatus.ready);
  });

  test('asking twice while the first call is out sends one request', () async {
    final q = await question();
    final gate = Completer<LlmCompletion>();
    final llm = _Llm(gate);
    final s = service(llm);
    final first = s.ask(q);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await s.ask(q);
    expect(llm.calls, 1);
    gate.complete(const LlmCompletion(content: _good));
    await first;
    expect((await db.chatMessagesDao.replyTo(q))!.status, ChatStatus.ready);
  });
}
