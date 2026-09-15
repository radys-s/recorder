import '../../data/db/app_database.dart';
import '../../data/db/tables/chat_messages_table.dart';

/// Merges the transcript, automatic answers and the chat into one list.
///
/// - an answer card goes right after the segment its question was heard in;
/// - a message the student typed goes before the first segment that started
///   after it was typed — the segment being recorded at that moment is the
///   one the student was reacting to, so the message follows it;
/// - an assistant reply goes right after the message it answers.
///
/// Cards whose segment is not in [segments] and replies whose message is gone
/// are kept at the end rather than dropped.
List<Object> mergeTimeline(
  List<TranscriptSegment> segments,
  List<AnswerCard> cards,
  List<ChatMessage> messages,
) {
  final cardsBySegment = <int, List<AnswerCard>>{};
  for (final card in cards) {
    (cardsBySegment[card.segmentId] ??= <AnswerCard>[]).add(card);
  }

  final userIds = {
    for (final m in messages)
      if (m.role == ChatRole.user) m.id,
  };
  final replies = <int, List<ChatMessage>>{};
  final standalone = <ChatMessage>[];
  for (final m in messages) {
    final to = m.replyTo;
    if (m.role == ChatRole.assistant && to != null && userIds.contains(to)) {
      (replies[to] ??= <ChatMessage>[]).add(m);
    } else {
      standalone.add(m);
    }
  }
  standalone.sort((a, b) {
    final byTime = a.atMs.compareTo(b.atMs);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });

  final items = <Object>[];
  var next = 0;
  void addMessage(ChatMessage m) {
    items.add(m);
    final own = replies[m.id];
    if (own != null) items.addAll(own);
  }

  for (final segment in segments) {
    while (next < standalone.length &&
        standalone[next].atMs <= segment.startMs) {
      addMessage(standalone[next++]);
    }
    items.add(segment);
    final own = cardsBySegment.remove(segment.id);
    if (own != null) items.addAll(own);
  }
  while (next < standalone.length) {
    addMessage(standalone[next++]);
  }
  for (final rest in cardsBySegment.values) {
    items.addAll(rest);
  }
  return items;
}
