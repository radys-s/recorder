import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/chat_messages_table.dart';

part 'chat_messages_dao.g.dart';

/// The chat that runs alongside a lesson.
@DriftAccessor(tables: [ChatMessages])
class ChatMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$ChatMessagesDaoMixin {
  ChatMessagesDao(super.db);

  static const maxLength = 4000;

  /// In recording order; messages typed at the same moment keep typing order.
  Stream<List<ChatMessage>> watchForMeeting(int meetingId) =>
      _forMeeting(meetingId).watch();

  Future<List<ChatMessage>> messages(int meetingId) =>
      _forMeeting(meetingId).get();

  SimpleSelectStatement<$ChatMessagesTable, ChatMessage> _forMeeting(
    int meetingId,
  ) =>
      select(chatMessages)
        ..where((t) => t.meetingId.equals(meetingId))
        ..orderBy([
          (t) => OrderingTerm.asc(t.atMs),
          (t) => OrderingTerm.asc(t.id),
        ]);

  Future<ChatMessage?> message(int id) =>
      (select(chatMessages)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// A message the student typed. Stored ready: context and rules need no
  /// request, and a question's reply is its own row.
  Future<int> addUserMessage({
    required int meetingId,
    required String text,
    required ChatIntent intent,
    required int atMs,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be blank');
    }
    return into(chatMessages).insert(
      ChatMessagesCompanion.insert(
        meetingId: meetingId,
        role: ChatRole.user,
        intent: intent,
        body: Value(
          trimmed.length <= maxLength ? trimmed : trimmed.substring(0, maxLength),
        ),
        atMs: atMs,
        status: ChatStatus.ready,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// A reply placeholder, shown as „Přemýšlím…" until [completeReply].
  Future<int> addPendingReply({
    required int meetingId,
    required int replyTo,
    required int atMs,
    ChatIntent intent = ChatIntent.question,
  }) =>
      into(chatMessages).insert(
        ChatMessagesCompanion.insert(
          meetingId: meetingId,
          role: ChatRole.assistant,
          intent: intent,
          atMs: atMs,
          status: ChatStatus.pending,
          replyTo: Value(replyTo),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> completeReply(
    int id, {
    required String short,
    String? detail,
    String? basis,
    String? sources,
  }) =>
      (update(chatMessages)..where((t) => t.id.equals(id))).write(
        ChatMessagesCompanion(
          status: const Value(ChatStatus.ready),
          short: Value(short),
          detail: Value(detail),
          basis: Value(basis),
          sources: Value(sources),
          body: const Value(''),
        ),
      );

  /// [reason] is Czech and shown on the reply.
  Future<void> failReply(int id, String reason) =>
      (update(chatMessages)..where((t) => t.id.equals(id))).write(
        ChatMessagesCompanion(
          status: const Value(ChatStatus.failed),
          body: Value(reason),
        ),
      );

  Future<void> markPending(int id) =>
      (update(chatMessages)..where((t) => t.id.equals(id))).write(
        const ChatMessagesCompanion(
          status: Value(ChatStatus.pending),
          body: Value(''),
        ),
      );

  Future<void> setIntent(int id, ChatIntent intent) =>
      (update(chatMessages)..where((t) => t.id.equals(id)))
          .write(ChatMessagesCompanion(intent: Value(intent)));

  /// The reply to [userMessageId], if one exists.
  Future<ChatMessage?> replyTo(int userMessageId) => (select(chatMessages)
        ..where((t) => t.replyTo.equals(userMessageId))
        ..orderBy([(t) => OrderingTerm.desc(t.id)])
        ..limit(1))
      .getSingleOrNull();

  /// Deletes a message and any reply to it.
  Future<void> deleteMessage(int id) => transaction(() async {
        await (delete(chatMessages)..where((t) => t.replyTo.equals(id))).go();
        await (delete(chatMessages)..where((t) => t.id.equals(id))).go();
      });

  /// A reply left pending by a killed app would spin forever.
  Future<int> failInterruptedReplies() =>
      (update(chatMessages)..where((t) => t.status.equalsValue(ChatStatus.pending)))
          .write(const ChatMessagesCompanion(
        status: Value(ChatStatus.failed),
        body: Value('Aplikace se zavřela dřív, než odpověď přišla.'),
      ));
}
