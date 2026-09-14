import 'package:drift/drift.dart' show Value;

import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/answer_cards_dao.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/db/daos/transcript_segments_dao.dart';
import 'answer_source.dart';
import 'grounding.dart';
import 'json_extract.dart';
import 'llm_provider.dart';
import 'question_detector.dart';
import 'web_answer_service.dart';

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
    this._webAnswers,
  );

  static const _tag = 'ai.answers';

  final LlmProvider _llm;
  final TranscriptSegmentsDao _segmentsDao;
  final AnswerCardsDao _answerCardsDao;
  final PreferencesDao _prefsDao;
  final WebAnswerService _webAnswers;

  /// Considers one freshly transcribed segment. Never throws.
  Future<void> handleSegment(TranscriptSegment segment, String text) async {
    try {
      // Read per segment rather than once per recording: the app-bar toggle
      // has to take effect on the next chunk, not the next meeting.
      final prefs = await _prefsDao.current();
      if (!prefs.liveAnswersEnabled) return;

      // The chunker cuts on silence, so a chunk that came in under the cap is
      // the room having gone quiet right after this passage — which is exactly
      // the rhetorical-question case the pre-filter otherwise misses.
      final endedOnPause = chunkEndedOnPause(
        Duration(milliseconds: segment.endMs - segment.startMs),
        kPauseCutMaxChunkDuration,
      );
      if (!looksLikeQuestion(text, endedOnPause: endedOnPause)) {
        AppLog.d(_tag, 'segment ${segment.id}: no question, no call');
        return;
      }

      // The one thing the model cannot see in the text. A question left
      // hanging reads as a statement on the page; what marks it as a question
      // is the silence after it, and the chunker measured that silence.
      const pauseNote = '\n\nThe room went quiet right after this passage.';

      final context = await _context(segment);
      final raw = await _llm.complete(
        model: kGroqAnswerModel,
        messages: [
          LlmMessage.system(_systemPrompt),
          LlmMessage.user(
            'Meeting so far:\n$context\n\nNewest passage:\n$text'
            '${endedOnPause ? pauseNote : ''}',
          ),
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

      final decision = _parse(raw);
      if (decision == null) {
        AppLog.e(_tag, 'segment ${segment.id}: unparseable response');
        return;
      }
      if (!decision.isQuestion) {
        AppLog.d(_tag, 'segment ${segment.id}: model says not a question');
        return;
      }
      if (!decision.onTopic) {
        AppLog.d(_tag, 'segment ${segment.id}: off topic, no card');
        return;
      }
      if (decision.answer.isEmpty) {
        AppLog.d(_tag, 'segment ${segment.id}: question but no answer');
        return;
      }

      // Nothing to hold the verdict to. The card would otherwise be headed by
      // the raw passage — and, with the web switch on, that passage would be
      // the search query, which is exactly the transcript slice the web hop
      // promises never to send.
      if (decision.quote.isEmpty && decision.question.isEmpty) {
        AppLog.d(_tag, 'segment ${segment.id}: question with no wording, no card');
        return;
      }

      // The question has to have been asked in the words the room actually
      // used. The previous segment counts too, since a chunk cut can split a
      // question from its first half.
      final previous = await _segmentsDao.previousTranscript(
        segment.meetingId,
        segment.sequence,
      );
      final spoken = '${previous ?? ''} $text';
      // ...but part of it has to be in the newest passage. A question that
      // lives only in the previous segment was that segment's to answer, and
      // letting it through here puts the same card in the timeline twice.
      final grounded = decision.quote.isNotEmpty
          ? isGroundedIn(decision.quote, spoken) &&
              isGroundedIn(decision.quote, text, minShare: 1 / 3)
          : isGroundedIn(decision.question, text, minShare: 1 / 3);
      if (!grounded) {
        AppLog.d(
          _tag,
          'segment ${segment.id}: ungrounded question dropped '
          '(quote "${decision.quote}", question "${decision.question}")',
        );
        return;
      }
      if (decision.confidence < kAnswerMinConfidence) {
        AppLog.d(
          _tag,
          'segment ${segment.id}: dropped, confidence ${decision.confidence}',
        );
        return;
      }

      final question =
          decision.question.isNotEmpty ? decision.question : decision.quote;

      var answer = decision.answer;
      var basis = decision.basis;
      List<AnswerSource> sources = const [];

      // The meeting always wins. A figure somebody said out loud two minutes
      // ago must never be overridden by something found on the internet, so
      // the web hop fires only for the two verdicts that already say the room
      // did not supply the answer.
      if (prefs.webAnswersEnabled && basis != 'meeting') {
        final web = await _webAnswers.lookUp(question);
        if (web != null) {
          answer = web.answer;
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

      final id = await _answerCardsDao.insertCard(
        AnswerCardsCompanion.insert(
          meetingId: segment.meetingId,
          segmentId: segment.id,
          question: question,
          answer: answer,
          basis: Value(basis),
          sources: Value(encodeAnswerSources(sources)),
          createdAt: DateTime.now(),
          dismissed: const Value(false),
        ),
      );
      AppLog.d(
        _tag,
        'segment ${segment.id}: card $id (${answer.length} chars, '
        'basis $basis, ${sources.length} source(s), '
        'confidence ${decision.confidence})',
      );
    } catch (e, st) {
      AppLog.e(_tag, 'segment ${segment.id} failed', e, st);
    }
  }

  /// The tail of the meeting *before* this segment.
  ///
  /// The question is very often answerable from what was already said, and the
  /// prompt asks the model to prefer exactly that — so the context is not
  /// decoration, it is where most good answers come from.
  ///
  /// The segment itself is left out: its text is already in the database by
  /// the time this runs, and it goes into the request on its own as the newest
  /// passage. Including it here too handed the model the same words twice,
  /// under two headings that told it they were different parts of the meeting.
  Future<String> _context(TranscriptSegment segment) async {
    final segments = await _segmentsDao.segmentsForMeeting(segment.meetingId);
    final parts = <String>[
      for (final s in segments)
        if (s.sequence < segment.sequence &&
            s.content != null &&
            s.content!.trim().isNotEmpty)
          s.content!.trim(),
    ];

    final joined = parts.join(' ');
    return joined.length <= kAnswerContextChars
        ? joined
        : joined.substring(joined.length - kAnswerContextChars);
  }

  /// JSON mode makes a well-formed object very likely, not certain, and
  /// reasoning models sometimes wrap it in prose. A malformed response means
  /// "no question found", never an exception thrown at the callback.
  static _AnswerDecision? _parse(String raw) {
    final decoded = extractJsonObject(raw);
    if (decoded == null) return null;

    final basis = _string(decoded['basis']).toLowerCase();
    return _AnswerDecision(
      isQuestion: _bool(decoded['is_question']) ?? false,
      // Only an explicit false filters. A response that forgot the field is
      // not evidence of small talk, and must not cost the user a card.
      onTopic: _bool(decoded['on_topic']) ?? true,
      quote: _string(decoded['quote']),
      question: _string(decoded['question']),
      answer: _string(decoded['answer']),
      // An unrecognised label is treated as "from the meeting", which is the
      // one that shows no badge — a wrong badge claiming outside knowledge
      // would be worse than none.
      basis: const {'meeting', 'knowledge', 'unknown'}.contains(basis)
          ? basis
          : 'meeting',
      confidence: _confidence(decoded['confidence']),
    );
  }

  static String _string(Object? value) =>
      value is String ? value.trim() : '';

  /// JSON mode guarantees an object, not the types inside it. Reasoning models
  /// write `"true"` or `1` often enough that reading only a literal `true`
  /// silently turned real questions into "not a question". Null means the
  /// value says nothing either way, and the caller picks the safe default.
  static bool? _bool(Object? value) {
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
  static double _confidence(Object? value) {
    final parsed = switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value.trim().replaceAll(',', '.')),
      _ => null,
    };
    if (parsed == null || parsed.isNaN || parsed < 0) return 0;
    if (parsed > 1 && parsed <= 100) return parsed / 100;
    return parsed > 1 ? 1 : parsed;
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
}

class _AnswerDecision {
  const _AnswerDecision({
    required this.isQuestion,
    required this.onTopic,
    required this.quote,
    required this.question,
    required this.answer,
    required this.basis,
    required this.confidence,
  });

  final bool isQuestion;
  final bool onTopic;
  final String quote;
  final String question;
  final String answer;
  final String basis;
  final double confidence;
}
