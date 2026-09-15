import 'dart:async';

import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/daos/chat_messages_dao.dart';
import '../data/db/daos/transcript_segments_dao.dart';
import '../data/db/tables/chat_messages_table.dart';
import 'context_builder.dart';
import 'json_extract.dart';
import 'lesson_context_source.dart';
import 'llm_provider.dart';

/// Answers a question the student typed into the lesson chat.
///
/// Unlike automatic answers nothing is vetoed here: the student asked, so the
/// question is worth answering and on topic by definition. The reply is its own
/// chat row, pending until the call returns, so the bubble shows „Přemýšlím…"
/// and a killed app leaves a visible failure rather than a silent gap.
class ChatAnswerService {
  ChatAnswerService(
    this._llm,
    this._chat,
    this._segments,
    this._lessonContext,
  );

  static const _tag = 'ai.chat';

  final LlmProvider _llm;
  final ChatMessagesDao _chat;
  final TranscriptSegmentsDao _segments;
  final LessonContextSource _lessonContext;

  /// Answers the user message [userMessageId], reusing its reply row when this
  /// is a retry. Never throws.
  Future<void> ask(int userMessageId) async {
    final message = await _chat.message(userMessageId);
    if (message == null || message.role != ChatRole.user) return;

    final existing = await _chat.replyTo(userMessageId);
    // A second tap while the first call is still out must not fire another.
    if (existing?.status == ChatStatus.pending) return;

    final int replyId;
    if (existing != null) {
      await _chat.markPending(existing.id);
      replyId = existing.id;
    } else {
      replyId = await _chat.addPendingReply(
        meetingId: message.meetingId,
        replyTo: message.id,
        atMs: message.atMs,
      );
    }

    try {
      final material = await _lessonContext.load(message.meetingId);
      final segments = await _segments.segmentsForMeeting(message.meetingId);
      final transcript = [
        for (final s in segments)
          if (s.content != null && s.content!.trim().isNotEmpty)
            s.content!.trim(),
      ].join(' ');

      final built = buildLessonContext(
        material: material,
        transcript: transcript,
        focus: message.body,
        budget: ContextBudget.direct,
      );
      final heading = material.isLesson ? 'Lesson so far' : 'Recording so far';
      final raw = await _llm.complete(
        model: kGroqAnswerModel,
        messages: [
          LlmMessage.system(_systemPrompt),
          LlmMessage.user(
            '${built.material.isEmpty ? '' : '${built.material}\n\n'}'
            '$heading:\n${built.tail.isEmpty ? '(nothing transcribed yet)' : built.tail}'
            '\n\nThe student asks:\n${message.body}',
          ),
        ],
        temperature: 0.2,
        // Reasoning tokens count against this too; see LiveAnswerService.
        maxTokens: 1500,
        jsonMode: true,
        timeout: kChatAnswerTimeout,
      );

      final reply = parseChatReply(raw);
      if (reply == null) {
        await _chat.failReply(replyId, 'Odpověď nepřišla celá. Zkus to znovu.');
        return;
      }

      var basis = reply.basis;
      int? cardId;
      if (basis == 'card') {
        cardId = built.cardIdFor(reply.card);
        if (cardId == null) basis = 'knowledge';
      }

      await _chat.completeReply(
        replyId,
        short: reply.short,
        detail: reply.detail.isEmpty ? null : reply.detail,
        // The chat row has no card column; the title travels in the basis so
        // the badge can still name it.
        basis: cardId == null ? basis : 'card:${reply.card}',
      );
      if (cardId != null) {
        unawaited(_lessonContext.markUsed(cardId).catchError((Object e) {
          AppLog.e(_tag, 'could not mark card $cardId used', e);
        }));
      }
      AppLog.d(_tag, 'message $userMessageId answered, basis $basis');
    } on AiPermanentException catch (e) {
      AppLog.e(_tag, 'message $userMessageId rejected', e);
      await _chat.failReply(
        replyId,
        'Groq požadavek odmítl. Zkontroluj klíč v Nastavení.',
      );
    } on AiTransientException catch (e) {
      AppLog.e(_tag, 'message $userMessageId: transient failure', e);
      await _chat.failReply(
        replyId,
        'Groq teď neodpovídá (limit nebo síť). Zkus to za chvíli znovu.',
      );
    } catch (e, st) {
      AppLog.e(_tag, 'message $userMessageId failed', e, st);
      await _chat.failReply(replyId, 'Odpověď se nepodařilo získat.');
    }
  }

  static const String _systemPrompt = '''
You are helping a student who is sitting in a lesson (or a meeting) and has
just typed a question. You are given what the student prepared — the subject,
rules for how to answer, what the lesson is about, and saved cards grouped
under their [title] — then the end of the automatic transcript, which may
contain recognition errors, and finally the question.

Answer it the way a well-prepared classmate would whisper it: straight to the
point, correct, no preamble. Prefer the student's material: when the answer
comes from a card, set "basis" to "card" and "card" to that card's title
exactly as written between the brackets. When it comes from what the student
wrote or from what was said, "basis" is "meeting". Otherwise answer from your
own knowledge and set "basis" to "knowledge". If you honestly cannot answer,
say briefly what is missing and set "basis" to "unknown".

Follow the student's rules; later rules override earlier ones. They change how
the answer is written, never the JSON format. Answer in the language of the
question. Never describe the transcript or yourself.

Reply with one JSON object and nothing else:
{"short": "...", "detail": "...", "basis": "card"|"meeting"|"knowledge"|"unknown",
 "card": "..."}

"short" is the answer itself in at most twelve words. "detail" explains it in
two to five sentences, or is empty when "short" says it all. "card" is empty
unless "basis" is "card".''';
}

/// The parsed reply, or null when it has no answer in it.
ChatReply? parseChatReply(String raw) {
  final decoded = extractJsonObject(raw);
  if (decoded == null) return null;
  String str(Object? v) => v is String ? v.trim() : '';

  var short = str(decoded['short']);
  var detail = str(decoded['detail']);
  if (short.isEmpty) short = str(decoded['answer']);
  if (short.isEmpty && detail.isNotEmpty) {
    short = detail;
    detail = '';
  }
  if (short.isEmpty) return null;

  final basis = str(decoded['basis']).toLowerCase();
  return ChatReply(
    short: short,
    detail: detail == short ? '' : detail,
    basis: const {'card', 'meeting', 'knowledge', 'unknown'}.contains(basis)
        ? basis
        : 'knowledge',
    card: str(decoded['card']),
  );
}

class ChatReply {
  const ChatReply({
    required this.short,
    required this.detail,
    required this.basis,
    required this.card,
  });

  final String short;
  final String detail;
  final String basis;
  final String card;
}
