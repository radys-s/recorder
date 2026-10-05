import 'dart:async';

import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/chat_messages_dao.dart';
import '../data/db/daos/transcript_segments_dao.dart';
import '../data/db/tables/chat_messages_table.dart';
import '../stt/refined_transcript.dart';
import 'context_builder.dart';
import 'json_extract.dart';
import 'lesson_context_source.dart';
import 'llm_provider.dart';
import 'photo_questions.dart';

/// Answers a question the student typed into the lesson chat.
///
/// Unlike automatic answers nothing is vetoed here: the student asked, so the
/// question is worth answering and on topic by definition. The reply is its own
/// chat row, pending until the call returns, so the bubble shows „Přemýšlím…"
/// and a killed app leaves a visible failure rather than a silent gap.
///
/// With a Gemini key the question goes to Gemini with a much larger share of
/// the lesson; if Gemini fails for any reason, Groq answers with its usual
/// budget, so a second key can only ever add answers, never lose one.
class ChatAnswerService {
  ChatAnswerService(
    this._llm,
    this._chat,
    this._segments,
    this._lessonContext, {
    this._gemini,
    this._hasGeminiKey,
    this._hasRoomyRoute,
    this.refinedFor,
    this.watchdog = kChatWatchdog,
  });

  static const _tag = 'ai.chat';

  final LlmProvider _llm;
  final ChatMessagesDao _chat;
  final TranscriptSegmentsDao _segments;
  final LessonContextSource _lessonContext;
  final LlmProvider? _gemini;
  final Future<bool> Function()? _hasGeminiKey;

  /// True when a service roomier than Groq's free tier can take the request.
  final Future<bool> Function()? _hasRoomyRoute;

  /// The refined windows of a meeting, preferred over live text once ready.
  final Future<List<RefinedSegment>> Function(int meetingId)? refinedFor;

  /// How long one question may take over every route together.
  final Duration watchdog;

  Future<bool> _roomy() async {
    final check = _hasRoomyRoute;
    if (check == null) return false;
    try {
      return await check();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _geminiAvailable() async {
    if (_gemini == null || _hasGeminiKey == null) return false;
    try {
      return await _hasGeminiKey();
    } catch (_) {
      return false;
    }
  }

  /// Answers the user message [userMessageId], reusing its reply row when this
  /// is a retry. Never throws.
  Future<void> ask(int userMessageId) async {
    final message = await _chat.message(userMessageId);
    if (message == null || message.role != ChatRole.user) return;
    // A reply under a photo retries as a photo answer, not as a question that
    // happens to be the text read off it.
    if (message.intent == ChatIntent.photo) {
      return askAboutPhoto(
        userMessageId,
        questions: extractQuestions(message.body),
      );
    }
    await _run(
      message,
      _Task(
        focus: message.body,
        asks: '\n\nThe student asks:\n${message.body}',
        system: _systemPrompt,
      ),
    );
  }

  /// Answers the questions on a photo, as a reply under the photo bubble.
  ///
  /// [questions] are the ones the model or `extractQuestions` found; without
  /// them the whole text read off the photo is handed over and the model finds
  /// them itself. Does nothing for a photo that is not read yet or has no
  /// text. Never throws.
  Future<void> askAboutPhoto(
    int photoMessageId, {
    List<String> questions = const [],
  }) async {
    final message = await _chat.message(photoMessageId);
    if (message == null ||
        message.role != ChatRole.user ||
        message.intent != ChatIntent.photo ||
        message.status != ChatStatus.ready) {
      return;
    }
    final text = message.body.trim();
    final description = (message.short ?? '').trim();
    if (text.isEmpty && questions.isEmpty) return;

    final numbered = [
      for (var i = 0; i < questions.length; i++) '${i + 1}) ${questions[i]}',
    ].join('\n');
    final buffer = StringBuffer(
      '\n\nThe student photographed this during the lesson. '
      'What is written on it:\n${text.isEmpty ? '(nothing readable)' : text}',
    );
    if (description.isNotEmpty) buffer.write('\n\nWhat it shows: $description');
    if (numbered.isNotEmpty) {
      buffer.write('\n\nThe questions on it:\n$numbered');
    }

    await _run(
      message,
      _Task(
        focus: questions.isEmpty ? text : questions.join(' '),
        asks: buffer.toString(),
        system: _photoSystemPrompt,
      ),
    );
  }

  Future<void> _run(ChatMessage message, _Task task) async {
    final userMessageId = message.id;
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
      // A hung call must end in a visible failure, never in „Přemýšlím…"
      // forever: the sum of both timeouts below can be a minute and a half.
      await _answer(message, replyId, task).timeout(watchdog);
    } on AiPermanentException catch (e) {
      AppLog.e(_tag, 'message $userMessageId rejected', e);
      await _chat.failReply(
        replyId,
        '${e.source ?? 'Služba'} požadavek odmítla. Zkontroluj klíč v Nastavení.',
      );
    } on AiTransientException catch (e) {
      AppLog.e(_tag, 'message $userMessageId: transient failure', e);
      await _chat.failReply(
        replyId,
        '${e.source ?? 'AI služba'} teď neodpovídá (limit nebo síť). '
        'Zkus to za chvíli znovu.',
      );
    } on TimeoutException catch (e) {
      AppLog.e(_tag, 'message $userMessageId: no answer in time', e);
      await _chat.failReply(replyId, 'Odpověď trvá moc dlouho. Zkus to znovu.');
    } catch (e, st) {
      AppLog.e(_tag, 'message $userMessageId failed', e, st);
      await _chat.failReply(replyId, 'Odpověď se nepodařilo získat.');
    }
  }

  /// The whole call for one question: context, Gemini then the router, parse,
  /// store. Throws what the providers throw; [ask] turns it into a failed row.
  Future<void> _answer(ChatMessage message, int replyId, _Task task) async {
    final material = await _lessonContext.load(message.meetingId);
    final segments = await _segments.segmentsForMeeting(message.meetingId);
    final transcript = refinedFor == null
        ? [
            for (final s in segments)
              if (s.content != null && s.content!.trim().isNotEmpty)
                s.content!.trim(),
          ].join(' ')
        : refinedOrLiveTranscript(
            segments,
            await refinedFor!(message.meetingId),
          );

    final heading = material.isLesson ? 'Lesson so far' : 'Recording so far';
    List<LlmMessage> prompt(LessonContext built) => [
      LlmMessage.system(task.system),
      LlmMessage.user(
        '${built.material.isEmpty ? '' : '${built.material}\n\n'}'
        '$heading:\n${built.tail.isEmpty ? '(nothing transcribed yet)' : built.tail}'
        '${task.asks}',
      ),
    ];

    LessonContext? built;
    String? raw;
    if (await _geminiAvailable()) {
      final wide = buildLessonContext(
        material: material,
        transcript: transcript,
        focus: task.focus,
        budget: ContextBudget.gemini,
      );
      try {
        raw = await _gemini!.complete(
          model: kGeminiModel,
          messages: prompt(wide),
          maxTokens: 4000,
          jsonMode: true,
          timeout: kGeminiChatTimeout,
        );
        built = wide;
      } on AiException catch (e) {
        AppLog.e(_tag, 'message ${message.id}: Gemini failed, using Groq', e);
      }
    }

    if (raw == null) {
      built = buildLessonContext(
        material: material,
        transcript: transcript,
        focus: task.focus,
        budget: await _roomy() ? ContextBudget.routed : ContextBudget.direct,
      );
      raw = await _llm.complete(
        model: kGroqAnswerModel,
        messages: prompt(built),
        temperature: 0.2,
        // Reasoning tokens count against this too; see LiveAnswerService.
        maxTokens: 1500,
        jsonMode: true,
        timeout: kChatAnswerTimeout,
      );
    }

    final reply = parseChatReply(raw);
    if (reply == null) {
      await _chat.failReply(replyId, 'Odpověď nepřišla celá. Zkus to znovu.');
      return;
    }

    var basis = reply.basis;
    int? cardId;
    if (basis == 'card') {
      cardId = built!.cardIdFor(reply.card);
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
      unawaited(
        _lessonContext.markUsed(cardId).catchError((Object e) {
          AppLog.e(_tag, 'could not mark card $cardId used', e);
        }),
      );
    }
    AppLog.d(_tag, 'message ${message.id} answered, basis $basis');
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

  static const String _photoSystemPrompt = '''
You are helping a student who is sitting in a lesson and has just photographed
a worksheet, slide or board. You are given what the student prepared (subject,
rules, cards), the end of the automatic transcript, the text read off the
photo, and the questions found on it.

Answer every question on the photo, in order, the way a well-prepared
classmate would: correct and to the point. Prefer the student's material and
what was said in the lesson; otherwise answer from your own knowledge. If a
question cannot be answered from the photo text alone, answer what you can and
say what is missing. Never answer something that is not a question or task on
the photo. Follow the student's rules; later rules override earlier ones. Answer
in the language of the questions. Never describe the photo or yourself.

Reply with one JSON object and nothing else:
{"short": "...", "detail": "...", "basis": "card"|"meeting"|"knowledge"|"unknown",
 "card": "..."}

"short" is at most twelve words: with one question the answer itself, with
several the answer to the first one. "detail" holds every answer on its own
line as "1) ...", "2) ...", each one to three sentences. "card" is empty unless
"basis" is "card".''';
}

/// One call's inputs: what the context is scored against, the user turn that
/// follows the lesson context, and the system prompt.
class _Task {
  const _Task({required this.focus, required this.asks, required this.system});

  final String focus;
  final String asks;
  final String system;
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
