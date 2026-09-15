import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/chat_messages_dao.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';

void main() {
  late AppDatabase db;
  late ChatMessagesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.chatMessagesDao;
  });
  tearDown(() => db.close());

  test('a user message is trimmed, capped and stored ready', () async {
    final id = await dao.addUserMessage(
        meetingId: 1, text: '  Čteme Babičku  ', intent: ChatIntent.context, atMs: 5);
    final m = (await dao.message(id))!;
    expect(m.body, 'Čteme Babičku');
    expect(m.role, ChatRole.user);
    expect(m.status, ChatStatus.ready);

    final longId = await dao.addUserMessage(
        meetingId: 1, text: 'x' * 9000, intent: ChatIntent.context, atMs: 6);
    expect((await dao.message(longId))!.body.length, ChatMessagesDao.maxLength);

    expect(
      () => dao.addUserMessage(
          meetingId: 1, text: '  ', intent: ChatIntent.context, atMs: 0),
      throwsArgumentError,
    );
  });

  test('a reply goes pending → ready, and is found by its question', () async {
    final q = await dao.addUserMessage(
        meetingId: 1, text: 'Kdo byl Proško?', intent: ChatIntent.question, atMs: 100);
    final r = await dao.addPendingReply(meetingId: 1, replyTo: q, atMs: 100);
    expect((await dao.replyTo(q))!.status, ChatStatus.pending);

    await dao.completeReply(r, short: 'Myslivec', detail: 'Z Babičky.', basis: 'card:Babička');
    final reply = (await dao.replyTo(q))!;
    expect(reply.status, ChatStatus.ready);
    expect(reply.short, 'Myslivec');
    expect(reply.basis, 'card:Babička');

    await dao.failReply(r, 'Nepovedlo se.');
    expect((await dao.message(r))!.body, 'Nepovedlo se.');
    await dao.markPending(r);
    expect((await dao.message(r))!.status, ChatStatus.pending);
  });

  test('messages are ordered by recording time and scoped to a meeting',
      () async {
    await dao.addUserMessage(meetingId: 1, text: 'b', intent: ChatIntent.context, atMs: 20);
    await dao.addUserMessage(meetingId: 1, text: 'a', intent: ChatIntent.rule, atMs: 10);
    await dao.addUserMessage(meetingId: 2, text: 'z', intent: ChatIntent.context, atMs: 0);
    expect((await dao.messages(1)).map((m) => m.body), ['a', 'b']);
  });

  test('deleting a question deletes its reply; interrupted replies fail',
      () async {
    final q = await dao.addUserMessage(
        meetingId: 1, text: 'Proč?', intent: ChatIntent.question, atMs: 0);
    await dao.addPendingReply(meetingId: 1, replyTo: q, atMs: 0);
    expect(await dao.failInterruptedReplies(), 1);
    expect((await dao.replyTo(q))!.status, ChatStatus.failed);

    await dao.setIntent(q, ChatIntent.rule);
    expect((await dao.message(q))!.intent, ChatIntent.rule);

    await dao.deleteMessage(q);
    expect(await dao.messages(1), isEmpty);
  });

  test('a fresh install listens with automatic sensitivity', () async {
    final prefs = await db.preferencesDao.current();
    expect(prefs.micSensitivity, MicSensitivity.auto);
  });
}
