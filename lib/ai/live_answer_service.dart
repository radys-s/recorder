import 'dart:async';

import 'package:drift/drift.dart' show Value;

import '../core/constants.dart';
import '../core/logging.dart';
import '../core/listening_diagnostics.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/answer_cards_dao.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/db/daos/transcript_segments_dao.dart';
import '../data/db/tables/transcript_segments_table.dart';
import 'answer_source.dart';
import 'context_builder.dart';
import 'grounding.dart';
import 'json_extract.dart';
import 'lesson_context_source.dart';
import 'llm_provider.dart';
import 'question_detector.dart';
import 'web_answer_service.dart';

/// What „Odpověz teď" came to, for the snackbar.
enum AnswerNowOutcome { answered, noQuestion, nothingHeard, failed }

/// Watches the transcript as it arrives and answers questions asked out loud.
///
/// Called from the queue worker's `onTranscribed` callback with `unawaited`, so
/// nothing here can slow the transcript down — a slow or failed answer costs
/// only itself. Failures are logged and dropped: the meeting is still being
/// recorded, and an error banner about a feature the user is not looking at
/// would be worse than silence.
class LiveAnswerService {
  LiveAnswerService(
    this._llm,
    this._segmentsDao,
    this._answerCardsDao,
    this._prefsDao,
    this._webAnswers, {
    LessonContextSource? lessonContext,
    this._gemini,
    this._hasGeminiKey,
    this.pollInterval = const Duration(milliseconds: 500),
    this.diagnostics,
  })
    // ignore: prefer_initializing_formals
    : _lessonContext = lessonContext;

  static const _tag = 'ai.answers';

  final LlmProvider _llm;
  final TranscriptSegmentsDao _segmentsDao;
  final AnswerCardsDao _answerCardsDao;
  final PreferencesDao _prefsDao;
  final WebAnswerService _webAnswers;
  final ListeningDiagnostics? diagnostics;
  final LessonContextSource? _lessonContext;

  /// Answers in a lesson when the student has a Gemini key; Groq otherwise,
  /// and after any Gemini failure.
  final LlmProvider? _gemini;
  final Future<bool> Function()? _hasGeminiKey;

  /// How often [answerNow] checks whether the last chunk has come back.
  final Duration pollInterval;

  /// Considers one freshly transcribed segment. Never throws.
  Future<void> handleSegment(TranscriptSegment segment, String text) async {
    try {
      // Read per segment rather than once per recording: the app-bar toggle
      // has to take effect on the next chunk, not the next meeting.
      final prefs = await _prefsDao.current();
      if (!prefs.liveAnswersEnabled) {
        _trace(
          segment,
          ListeningStage.candidate,
          ListeningOutcome.rejected,
          'live_answers_disabled',
        );
        return;
      }

      // The chunker cuts on silence, so a chunk that came in under the cap is
      // the room having gone quiet right after this passage — which is exactly
      // the rhetorical-question case the pre-filter otherwise misses.
      final endedOnPause = switch (segment.cutReason) {
        'silence' || 'dip' => true,
        'hardCap' || 'manual' || 'flush' => false,
        _ => chunkEndedOnPause(
          Duration(milliseconds: segment.endMs - segment.startMs),
          kPauseCutMaxChunkDuration,
        ),
      };
      if (!looksLikeQuestion(text, endedOnPause: endedOnPause)) {
        AppLog.d(_tag, 'segment ${segment.id}: no question, no call');
        _trace(
          segment,
          ListeningStage.candidate,
          ListeningOutcome.rejected,
          'not_question_candidate',
          metrics: {'ended_on_pause': endedOnPause},
        );
        return;
      }
      _trace(
        segment,
        ListeningStage.candidate,
        ListeningOutcome.progress,
        'candidate_detected',
        metrics: {'ended_on_pause': endedOnPause},
      );

      final previous = await _segmentsDao.previousTranscript(
        segment.meetingId,
        segment.sequence,
      );
      final (:request, :decision) = await _decide(
        segment,
        text,
        previous: previous,
        note: endedOnPause ? _pauseNote : '',
      );
      if (decision == null) {
        AppLog.e(_tag, 'segment ${segment.id}: unparseable response');
        _trace(
          segment,
          ListeningStage.decision,
          ListeningOutcome.rejected,
          'unparseable_decision',
        );
        return;
      }
      if (!decision.isQuestion) {
        AppLog.d(_tag, 'segment ${segment.id}: model says not a question');
        _trace(
          segment,
          ListeningStage.decision,
          ListeningOutcome.rejected,
          'model_not_question',
        );
        return;
      }
      if (!decision.onTopic) {
        AppLog.d(_tag, 'segment ${segment.id}: off topic, no card');
        _trace(
          segment,
          ListeningStage.decision,
          ListeningOutcome.rejected,
          'off_topic',
        );
        return;
      }
      if (decision.shortAnswer.isEmpty) {
        AppLog.d(_tag, 'segment ${segment.id}: question but no answer');
        _trace(
          segment,
          ListeningStage.decision,
          ListeningOutcome.rejected,
          'empty_answer',
        );
        return;
      }

      // Nothing to hold the verdict to. The card would otherwise be headed by
      // the raw passage — and, with the web switch on, that passage would be
      // the search query, which is exactly the transcript slice the web hop
      // promises never to send.
      if (decision.quote.isEmpty && decision.question.isEmpty) {
        AppLog.d(
          _tag,
          'segment ${segment.id}: question with no wording, no card',
        );
        _trace(
          segment,
          ListeningStage.decision,
          ListeningOutcome.rejected,
          'missing_wording',
        );
        return;
      }

      // The question has to have been asked in the words the room actually
      // used. The previous segment counts too, since a chunk cut can split a
      // question from its first half.
      final spoken = '${previous ?? ''} $text';
      // ...but part of it has to be in the newest passage. A question that
      // lives only in the previous segment was that segment's to answer, and
      // letting it through here puts the same card in the timeline twice.
      final quoteHolds = decision.quote.isNotEmpty
          ? isGroundedIn(decision.quote, spoken) &&
                isGroundedIn(decision.quote, text, minShare: 1 / 3)
          : isGroundedIn(decision.question, text, minShare: 1 / 3);
      // The quote vouches for the passage, not for the card's heading. A quote
      // of a word or two ("A kolik?") passes any check, and the tidied question
      // shown above the answer was then free to be one nobody asked. Tidying
      // may borrow the subject from earlier in the meeting — or, in a lesson,
      // from the student's own material — so that is what the question is held
      // to; but its words must have been said or written somewhere.
      final grounded =
          quoteHolds &&
          isGroundedIn(
            decision.question,
            '${request.groundingText} $spoken',
            minShare: 1 / 2,
          );
      if (!grounded) {
        AppLog.d(
          _tag,
          'segment ${segment.id}: ungrounded question dropped '
          '(quote "${decision.quote}", question "${decision.question}")',
        );
        _trace(
          segment,
          ListeningStage.decision,
          ListeningOutcome.rejected,
          'ungrounded_question',
        );
        return;
      }
      if (decision.confidence < kAnswerMinConfidence) {
        AppLog.d(
          _tag,
          'segment ${segment.id}: dropped, confidence ${decision.confidence}',
        );
        _trace(
          segment,
          ListeningStage.decision,
          ListeningOutcome.rejected,
          'answer_confidence_below_threshold',
          metrics: {'confidence': decision.confidence},
        );
        return;
      }

      await _insert(segment, decision, request, prefs.webAnswersEnabled);
    } catch (e, st) {
      AppLog.e(_tag, 'segment ${segment.id} failed', e, st);
      _trace(
        segment,
        ListeningStage.decision,
        ListeningOutcome.failed,
        'processing_error',
      );
    }
  }

  /// „Odpověz teď": the student says a question was just asked and the app
  /// missed it. Waits for the last chunk to come back, then answers from the
  /// end of the lesson with none of the automatic path's vetoes — the student
  /// has already decided there was a question worth answering.
  ///
  /// [cutAtMs] is the recording offset at the tap, when known; segments ending
  /// before it are what is waited for. Never throws.
  Future<AnswerNowOutcome> answerNow(
    int meetingId, {
    int? cutAtMs,
    Duration maxWait = kAnswerNowMaxWait,
  }) async {
    try {
      final deadline = DateTime.now().add(maxWait);
      var segments = await _segmentsDao.segmentsForMeeting(meetingId);
      while (_waitingOn(segments, cutAtMs) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
        segments = await _segmentsDao.segmentsForMeeting(meetingId);
      }

      final heard = [
        for (final s in segments)
          if (s.content != null && s.content!.trim().isNotEmpty) s,
      ];
      if (heard.isEmpty) return AnswerNowOutcome.nothingHeard;

      final last = heard.last;
      final windowStart = last.endMs - kAnswerNowWindow.inMilliseconds;
      final window = [
        for (final s in heard)
          if (s.endMs > windowStart) s,
      ];
      final text = window.map((s) => s.content!.trim()).join(' ');
      final earliest = window.first;

      final (:request, :decision) = await _decide(
        earliest,
        text,
        previous: null,
        note: _answerNowNote,
      );
      if (decision == null) {
        AppLog.e(_tag, 'answer now in meeting $meetingId: unparseable');
        return AnswerNowOutcome.failed;
      }
      final hasWording =
          decision.question.isNotEmpty || decision.quote.isNotEmpty;
      if (!decision.isQuestion || decision.shortAnswer.isEmpty || !hasWording) {
        AppLog.d(_tag, 'answer now in meeting $meetingId: no question found');
        return AnswerNowOutcome.noQuestion;
      }

      final prefs = await _prefsDao.current();
      await _insert(last, decision, request, prefs.webAnswersEnabled);
      return AnswerNowOutcome.answered;
    } catch (e, st) {
      AppLog.e(_tag, 'answer now in meeting $meetingId failed', e, st);
      return AnswerNowOutcome.failed;
    }
  }

  static bool _waitingOn(List<TranscriptSegment> segments, int? cutAtMs) =>
      segments.any(
        (s) =>
            (s.status == SegmentStatus.pending ||
                s.status == SegmentStatus.uploading) &&
            (cutAtMs == null || s.startMs < cutAtMs),
      );

  static const _pauseNote = '\n\nThe room went quiet right after this passage.';

  static const _answerNowNote =
      '\n\nThe student pressed "answer now": a '
      'question was asked in this passage, most likely near its end, and '
      'nobody has answered it. Find the most recent one and answer it. Do not '
      'judge whether it is on topic, and set "is_question" to false only if '
      'there is truly no question in it.';

  Future<bool> _geminiAvailable() async {
    if (_gemini == null || _hasGeminiKey == null) return false;
    try {
      return await _hasGeminiKey();
    } catch (_) {
      return false;
    }
  }

  /// Builds the request and asks. A lesson goes to Gemini with a far wider look
  /// when the key is there; anything Gemini throws (a 429 on the free tier
  /// included) sends the same passage to Groq with the usual budget, so the
  /// second key can only add answers.
  Future<({_Request request, AnswerDecision? decision})> _decide(
    TranscriptSegment segment,
    String text, {
    required String? previous,
    required String note,
  }) async {
    final material = await _material(segment.meetingId);
    final earlier = await _earlierTranscript(segment);

    if (material != null && material.isLesson && await _geminiAvailable()) {
      final wide = _request(
        material,
        earlier,
        text,
        previous: previous,
        note: note,
        budget: ContextBudget.geminiLive,
      );
      try {
        final raw = await _gemini!.complete(
          model: kGeminiModel,
          messages: [
            LlmMessage.system(wide.system),
            LlmMessage.user(wide.user),
          ],
          maxTokens: 3000,
          jsonMode: true,
          timeout: kGeminiLiveAnswerTimeout,
        );
        return (request: wide, decision: parseAnswerDecision(raw));
      } on AiException catch (e) {
        AppLog.e(_tag, 'segment ${segment.id}: Gemini failed, using Groq', e);
      }
    }

    final request = _request(
      material,
      earlier,
      text,
      previous: previous,
      note: note,
      budget: ContextBudget.automatic,
    );
    return (request: request, decision: await _ask(request));
  }

  /// The request for the passage [text]: the meeting path exactly as it always
  /// was, or the lesson path when the student gave the AI anything.
  _Request _request(
    LessonMaterial? material,
    String earlier,
    String text, {
    required String? previous,
    required String note,
    required ContextBudget budget,
  }) {
    if (material == null || material.isEmpty) {
      final context = earlier.length <= kAnswerContextChars
          ? earlier
          : earlier.substring(earlier.length - kAnswerContextChars);
      return _Request(
        system: _systemPrompt,
        user: 'Meeting so far:\n$context\n\nNewest passage:\n$text$note',
        groundingText: context,
        lesson: null,
      );
    }

    final built = buildLessonContext(
      material: material,
      transcript: earlier,
      focus: '${previous ?? ''} $text',
      budget: budget,
    );
    final heading = material.isLesson ? 'Lesson so far' : 'Meeting so far';
    return _Request(
      system:
          '$_systemPrompt\n\n'
          '${material.isLesson ? _lessonPrompt : _rulesPrompt}',
      user:
          '${built.material}\n\n$heading:\n${built.tail}\n\n'
          'Newest passage:\n$text$note',
      groundingText: '${built.material} ${built.tail}',
      lesson: built,
    );
  }

  Future<LessonMaterial?> _material(int meetingId) async {
    final source = _lessonContext;
    if (source == null) return null;
    try {
      return await source.load(meetingId);
    } catch (e, st) {
      // A lesson without its material still deserves the plain answer.
      AppLog.e(_tag, 'lesson material for meeting $meetingId failed', e, st);
      return null;
    }
  }

  Future<AnswerDecision?> _ask(_Request request) async {
    final raw = await _llm.complete(
      model: kGroqAnswerModel,
      messages: [
        LlmMessage.system(request.system),
        LlmMessage.user(request.user),
      ],
      temperature: 0.2,
      // Generous for a three-sentence answer, because `max_tokens` also
      // bounds the model's reasoning tokens, and gpt-oss spends most of its
      // budget there. Run out mid-object and Groq rejects the whole
      // generation with a 400 ("Failed to validate JSON") rather than
      // returning the truncated text — which is exactly what a tight budget
      // produced here the first time.
      maxTokens: 1200,
      jsonMode: true,
      timeout: kAnswerTimeout,
    );
    return parseAnswerDecision(raw);
  }

  Future<bool> _insert(
    TranscriptSegment segment,
    AnswerDecision decision,
    _Request request,
    bool webEnabled,
  ) async {
    final question = decision.question.isNotEmpty
        ? decision.question
        : decision.quote;

    var answer = decision.shortAnswer;
    String? detail = decision.detail.isEmpty ? null : decision.detail;
    var basis = decision.basis;
    List<AnswerSource> sources = const [];

    // A card can be named only if the model was shown it; anything else is the
    // model's own knowledge wearing a card's name.
    int? cardId;
    if (basis == 'card') {
      cardId = request.lesson?.cardIdFor(decision.card);
      if (cardId == null) basis = 'knowledge';
    }

    // The meeting always wins, and so does the student's own material. A
    // figure somebody said out loud two minutes ago must never be overridden
    // by something found on the internet, so the web hop fires only for the
    // two verdicts that already say nobody supplied the answer.
    if (webEnabled && (basis == 'knowledge' || basis == 'unknown')) {
      final web = await _webAnswers.lookUp(question);
      if (web != null) {
        answer = web.answer;
        detail = null;
        sources = web.sources;
        basis = 'web';
      } else {
        // Failure, timeout or an empty reply: keep what the first call
        // produced rather than losing the card.
        AppLog.d(
          _tag,
          'segment ${segment.id}: web hop gave nothing, keeping $basis',
        );
      }
    }

    final inserted = await _answerCardsDao.insertCardIfAbsentForSegment(
      AnswerCardsCompanion.insert(
        meetingId: segment.meetingId,
        segmentId: segment.id,
        question: question,
        answer: answer,
        detail: Value(detail),
        basis: Value(basis),
        cardId: Value(cardId),
        sources: Value(encodeAnswerSources(sources)),
        createdAt: DateTime.now(),
        dismissed: const Value(false),
      ),
    );
    if (!inserted.inserted) {
      _trace(
        segment,
        ListeningStage.card,
        ListeningOutcome.rejected,
        'duplicate_segment',
      );
      return false;
    }
    if (cardId != null) {
      unawaited(
        _lessonContext?.markUsed(cardId).catchError((Object e) {
          AppLog.e(_tag, 'could not mark card $cardId used', e);
        }),
      );
    }
    AppLog.d(
      _tag,
      'segment ${segment.id}: card ${inserted.id} (${answer.length} chars, '
      'basis $basis, ${sources.length} source(s), '
      'confidence ${decision.confidence})',
    );
    _trace(
      segment,
      ListeningStage.card,
      ListeningOutcome.accepted,
      'accepted',
      metrics: {'basis': basis, 'confidence': decision.confidence},
    );
    return true;
  }

  void _trace(
    TranscriptSegment segment,
    ListeningStage stage,
    ListeningOutcome outcome,
    String reason, {
    Map<String, Object?> metrics = const {},
  }) {
    diagnostics?.record(
      stage,
      outcome,
      reason,
      meetingId: segment.meetingId,
      sequence: segment.sequence,
      segmentId: segment.id,
      metrics: metrics,
    );
  }

  /// The meeting *before* this segment, whole.
  ///
  /// The question is very often answerable from what was already said, and the
  /// prompt asks the model to prefer exactly that — so the context is not
  /// decoration, it is where most good answers come from.
  ///
  /// The segment itself is left out: its text is already in the database by
  /// the time this runs, and it goes into the request on its own as the newest
  /// passage. Including it here too handed the model the same words twice,
  /// under two headings that told it they were different parts of the meeting.
  Future<String> _earlierTranscript(TranscriptSegment segment) async {
    final segments = await _segmentsDao.segmentsForMeeting(segment.meetingId);
    return [
      for (final s in segments)
        if (s.sequence < segment.sequence &&
            s.content != null &&
            s.content!.trim().isNotEmpty)
          s.content!.trim(),
    ].join(' ');
  }

  /// English instructions, Czech output — same reasoning as the notes prompts:
  /// the instruction-following is steadier, and the output language is pinned
  /// by its own rule rather than by the language the rules happen to be in.
  ///
  /// The examples are Czech on purpose. Everything the first version of this
  /// prompt got wrong was a matter of register rather than of fact — "To nebylo
  /// řešeno.", "Tato otázka nebyla v průběhu jednání zodpovězena." — and a rule
  /// saying "write like a colleague" does not fix that on its own. A pair of
  /// contrastive examples in the output language does.
  ///
  /// The examples deliberately describe a *different* meeting from anything the
  /// app is likely to hear. The first version used the same two questions as the
  /// Czech test recording, and the model duly answered one of them by copying
  /// the example's closing clause and dropping the facts the meeting had
  /// actually supplied — the example stopped teaching register and started
  /// supplying content.
  static const String _systemPrompt = '''
You are sitting in on a meeting, following it through an automatic transcript.
The transcript may contain recognition errors and carries no speaker labels.

You are given the meeting so far and the newest passage. First decide whether
the newest passage contains a question somebody asked out loud that a short
answer would genuinely help with. Only the newest passage counts: a question
from earlier in the meeting, or one you think somebody might want to ask, is
not in it. These do not count:
- tag questions and turns of phrase ("že jo?", "right?", "což?"),
- a question the transcript itself answers immediately afterwards,
- a question about the meeting's own procedure ("můžeme začít?").

A question does not need a question mark, and does not need to be addressed
to anybody. The transcript drops question marks all the time, so judge by
meaning, never by punctuation. Somebody saying what they do not know or would
like to know — "nevím, kdo to má podepsat", "zajímalo by mě, jestli to projde
auditem", "stihne se to, nebo ne" — has asked a question. So has somebody
thinking out loud: "no a to je právě ta otázka, jestli se nám to vyplatí",
"zůstává otázka, co na to úřad". When you are told the room went quiet right
after it, that is the room waiting for an answer nobody in it has, and it is
worth answering — often more than the ones asked outright.

Then decide whether the question belongs to the meeting. People drift into
private small talk — what to have for dinner, the weather, the weekend, a
joke — and a question from that is not what you are here for: set "on_topic"
to false and leave "answer" empty. Judge by what the meeting so far is about;
if the meeting itself is about that subject, the question is on topic. When
the meeting has barely started, a work or factual question is on topic and a
question about somebody's private life is not. When you use the meeting so far
for an answer, ignore its small talk the same way.

If it is a question and on topic, answer it the way a well-prepared colleague
across the table would: straight to the point, no throat-clearing. Work through
these in order and stop at the first that applies:

1. Answer from the meeting. Use what was said — including combining two things
   that were said and doing the arithmetic. If the budget is two million and
   forty percent is spent, the answer is that roughly 1.2 million is left. Do
   the sum. Use only what the transcript actually contains: never present as
   said something nobody said, and never attach a name to a statement the
   transcript does not attach it to. Set "basis" to "meeting".
2. Answer from your own knowledge, when the question does not depend on this
   meeting: a definition, a rule, a standard practice, a general calculation.
   Set "basis" to "knowledge".
3. Only when the question is about this meeting or this company and nobody has
   said the answer. Give what the meeting does have that bears on this question
   — the decision next to it, the number next to it, the person nearest to it —
   and then what is still missing. A fact that has nothing to do with the
   question is not an answer: if nothing said so far bears on it, one short
   sentence naming what has not been settled is the whole answer, and padding
   it out is worse than leaving it that short. Do not open by repeating the
   question back. Set "basis" to "unknown".

How the answer must be written:
- In the language of the transcript. A Czech transcript gets a Czech answer.
- One to three plain sentences with verbs. No bullets, no headings, no
  preamble, no repeating the question back.
- Never describe the transcript or yourself. Phrases like "v přepisu",
  "v záznamu", "v předešlé části", "nebylo zmíněno" must not appear — the
  person reading this is sitting in the meeting, not reading a document about
  it.
- Never let "I do not know" be the whole answer. Say what is known and what is
  missing.
- Give the number, the name or the date whenever there is one. Vague is worse
  than short.

Examples of the difference. They come from a different meeting than the one you
are listening to — a warehouse that ships 400 parcels a day, where a new line
is expected to add a quarter and would run two shifts. Take the register from
them, never the content:

  Q: "Kolik toho zvládneme, až ta linka pojede?"
  bad:  "Není to uvedeno v předešlé části záznamu."
  good: "Zhruba 500 zásilek denně — ke čtyřem stům přidá nová linka asi
         čtvrtinu."

  Q: "Kdo bude tu linku obsluhovat?"
  bad:  "Tato otázka nebyla v průběhu jednání zodpovězena."
  good: "Poběží na dvě směny, takže na ni bude potřeba dvojí obsazení. Kdo na
         nich bude, je jediné, co k tomu zatím nepadlo."

Reply with one JSON object and nothing else:
{"is_question": true|false, "on_topic": true|false, "quote": "...",
 "question": "...", "answer": "...",
 "basis": "meeting"|"knowledge"|"unknown", "confidence": 0.0}

"quote" is the words of the newest passage in which the question was asked,
copied exactly as they stand there — not tidied, not reworded. "question" is
that same question tidied into one clear sentence, keeping the speaker's own
words. "confidence" is between 0 and 1: how sure you are that this really was
a question worth answering. When "is_question" is false, leave "quote",
"question" and "answer" empty.''';

  /// Appended when the user set rules but this is not a lesson.
  static const String _rulesPrompt = '''
The block before the transcript holds rules the user set for how you answer.
Follow them; later rules override earlier ones. They change how the answer is
written, never the JSON format or the decision whether something was a question.

Add two fields to the JSON object: "short" — the answer itself in at most
twelve words, no preamble — and "detail" — the explanation in two to five
sentences, or empty when "short" says it all. Put the same text as "short"
into "answer".''';

  /// Appended in a lesson: the room is a classroom and the user a student.
  static const String _lessonPrompt = '''
Class mode. This is a school lesson and you are helping a student sitting in
it; "meeting" in the instructions above means this lesson. The block before the
transcript is what the student prepared: the subject, rules for how to answer,
what the student says the lesson is about, and saved cards grouped under their
[title].

- On topic means about the subject matter: the subject, the cards, what the
  student says the lesson is about, or what is being taught right now. Classroom
  logistics ("můžu jít na záchod?", "kdy se píše test?"), discipline, handing in
  homework, breaks and chatter between students are off topic.
- A teacher asking the class a question is exactly what you are here for —
  answer it the way a well-prepared student would.
- Prefer the student's material. When the answer comes from a card, set "basis"
  to "card" and "card" to that card's title exactly as written between the
  brackets. When it comes from what the student wrote about the lesson or from
  what was said in the lesson, "meeting". Only then general knowledge.
- Follow the student's rules; later rules override earlier ones. They change how
  the answer is written, never the JSON format.

Add three fields to the JSON object: "short" — the answer itself in at most
twelve words, no preamble, something the student could say out loud; "detail"
— the explanation in two to five sentences, or empty when "short" says it all;
"card" — the card's title when "basis" is "card", otherwise empty. Put the same
text as "short" into "answer". "basis" may also be "card".''';
}

class _Request {
  const _Request({
    required this.system,
    required this.user,
    required this.groundingText,
    required this.lesson,
  });

  final String system;
  final String user;

  /// What a tidied question may borrow its words from besides the passage.
  final String groundingText;

  /// The lesson context that was sent, for resolving a named card.
  final LessonContext? lesson;
}

/// JSON mode makes a well-formed object very likely, not certain, and
/// reasoning models sometimes wrap it in prose. A malformed response means
/// "no question found", never an exception thrown at the callback.
AnswerDecision? parseAnswerDecision(String raw) {
  final decoded = extractJsonObject(raw);
  if (decoded == null) return null;

  final basis = _string(decoded['basis']).toLowerCase();
  return AnswerDecision(
    isQuestion: _bool(decoded['is_question']) ?? false,
    // Only an explicit false filters. A response that forgot the field is
    // not evidence of small talk, and must not cost the user a card.
    onTopic: _bool(decoded['on_topic']) ?? true,
    quote: _string(decoded['quote']),
    question: _string(decoded['question']),
    answer: _string(decoded['answer']),
    short: _string(decoded['short']),
    detail: _string(decoded['detail']),
    card: _string(decoded['card']),
    // An unrecognised label is treated as "from the meeting", which is the
    // one that shows no badge — a wrong badge claiming outside knowledge
    // would be worse than none.
    basis: const {'meeting', 'knowledge', 'unknown', 'card'}.contains(basis)
        ? basis
        : 'meeting',
    confidence: _confidence(decoded['confidence']),
  );
}

String _string(Object? value) => value is String ? value.trim() : '';

/// JSON mode guarantees an object, not the types inside it. Reasoning models
/// write `"true"` or `1` often enough that reading only a literal `true`
/// silently turned real questions into "not a question". Null means the
/// value says nothing either way, and the caller picks the safe default.
bool? _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.trim().toLowerCase()) {
      'true' || 'yes' || '1' || 'ano' => true,
      'false' || 'no' || '0' || 'ne' => false,
      _ => null,
    };
  }
  return null;
}

/// The same leniency for the score: `"0.8"`, a Czech `"0,8"`, and a
/// percentage (`85`) all mean what they plainly mean. Anything unreadable is
/// zero, which drops the card — the cheap direction to be wrong in.
double _confidence(Object? value) {
  final parsed = switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim().replaceAll(',', '.')),
    _ => null,
  };
  if (parsed == null || parsed.isNaN || parsed < 0) return 0;
  if (parsed > 1 && parsed <= 100) return parsed / 100;
  return parsed > 1 ? 1 : parsed;
}

class AnswerDecision {
  const AnswerDecision({
    required this.isQuestion,
    required this.onTopic,
    required this.quote,
    required this.question,
    required this.answer,
    required this.short,
    required this.detail,
    required this.card,
    required this.basis,
    required this.confidence,
  });

  final bool isQuestion;
  final bool onTopic;
  final String quote;
  final String question;
  final String answer;
  final String short;
  final String detail;
  final String card;
  final String basis;
  final double confidence;

  /// The line shown on the card: the short answer when the model gave one.
  String get shortAnswer => short.isNotEmpty ? short : answer;
}
