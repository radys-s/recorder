import '../../data/db/app_database.dart';
import '../../data/db/tables/chat_messages_table.dart';
import '../../data/db/tables/refined_segments_table.dart';
import '../../stt/refined_transcript.dart';

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

/// Swaps the live segments of [items] for the refined windows that cover
/// them, keeping cards and chat messages where [mergeTimeline] put them.
///
/// - a ready window takes the place of the first live segment it covers and
///   the rest of its live segments drop out; cards and messages in between
///   stay, so they now follow the window;
/// - a ready window that heard nothing while the live pass heard something is
///   left out and the live text stays (see [refinedOrLivePieces]);
/// - a failed window is shown before its live segments, which stay, so the
///   student sees both the problem and the text there is;
/// - a window with no visible live segment (the live pass skipped the whole
///   stretch as silence) goes in by time.
List<Object> withRefinedWindows(
  List<Object> items,
  List<TranscriptSegment> allSegments,
  List<RefinedSegment> refined,
) {
  final replacing = <int, RefinedSegment>{};
  final shown = <RefinedSegment>[];
  final failedAt = <int, RefinedSegment>{};
  for (final w in refined) {
    final inside = chunksIn(allSegments, w.startMs, w.endMs);
    if (w.status == RefinedStatus.failed) {
      shown.add(w);
      if (inside.isNotEmpty) failedAt[inside.first.id] = w;
      continue;
    }
    if (w.status != RefinedStatus.ready) continue;
    final text = w.content?.trim() ?? '';
    if (text.isEmpty) continue;
    shown.add(w);
    for (final s in inside) {
      replacing[s.id] = w;
    }
  }

  final emitted = <int>{};
  final out = <Object>[];
  for (final item in items) {
    if (item is TranscriptSegment) {
      final failed = failedAt[item.id];
      if (failed != null && emitted.add(failed.id)) out.add(failed);
      final w = replacing[item.id];
      if (w != null) {
        if (emitted.add(w.id)) out.add(w);
        continue;
      }
    }
    out.add(item);
  }

  for (final w in shown) {
    if (emitted.contains(w.id)) continue;
    final at = out.indexWhere((o) =>
        (o is TranscriptSegment && o.startMs >= w.startMs) ||
        (o is RefinedSegment && o.startMs >= w.startMs));
    if (at < 0) {
      out.add(w);
    } else {
      out.insert(at, w);
    }
  }
  return out;
}
