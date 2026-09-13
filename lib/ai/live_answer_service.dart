import 'package:drift/drift.dart' show Value;

import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/answer_cards_dao.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/db/daos/transcript_segments_dao.dart';
import 'answer_source.dart';
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
      if (!decision.isQuestion || decision.answer.isEmpty) {
        AppLog.d(_tag, 'segment ${segment.id}: model says not a question');
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
          decision.question.isEmpty ? text.trim() : decision.question;

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

  /// The tail of the meeting up to and including this segment.
  ///
  /// The question is very often answerable from what was already said, and the
  /// prompt asks the model to prefer exactly that — so the context is not
  /// decoration, it is where most good answers come from.
  Future<String> _context(TranscriptSegment segment) async {
    final segments = await _segmentsDao.segmentsForMeeting(segment.meetingId);
    final parts = <String>[
      for (final s in segments)
        if (s.sequence <= segment.sequence &&
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

    final confidence = decoded['confidence'];
    final basis = _string(decoded['basis']).toLowerCase();
    return _AnswerDecision(
      isQuestion: decoded['is_question'] == true,
      question: _string(decoded['question']),
      answer: _string(decoded['answer']),
      // An unrecognised label is treated as "from the meeting", which is the
      // one that shows no badge — a wrong badge claiming outside knowledge
      // would be worse than none.
      basis: const {'meeting', 'knowledge', 'unknown'}.contains(basis)
          ? basis
          : 'meeting',
      confidence: confidence is num ? confidence.toDouble() : 0,
    );
  }

  static String _string(Object? value) =>
      value is String ? value.trim() : '';

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
answer would genuinely help with. These do not count:
- tag questions and turns of phrase ("že jo?", "right?", "což?"),
- a question the transcript itself answers immediately afterwards,
- a question about the meeting's own procedure ("můžeme začít?").

A question does not need a question mark, and does not need to be addressed
to anybody. Somebody thinking out loud — "no a to je právě ta otázka, jestli
se nám to vyplatí", "zůstává otázka, co na to úřad" — has put a real
question on the table. When you are told the room went quiet right after
it, that is the room waiting for an answer nobody in it has, and it is
worth answering — often more than the ones asked outright.

If it does, answer it the way a well-prepared colleague across the table would:
straight to the point, no throat-clearing. Work through these in order and stop
at the first that applies:

1. Answer from the meeting. Use what was said — including combining two things
   that were said and doing the arithmetic. If the budget is two million and
   forty percent is spent, the answer is that roughly 1.2 million is left. Do
   the sum. Set "basis" to "meeting".
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
{"is_question": true|false, "question": "...", "answer": "...",
 "basis": "meeting"|"knowledge"|"unknown", "confidence": 0.0}

"question" is the question as it was asked, tidied up. "confidence" is between
0 and 1: how sure you are that this really was a question worth answering.
When "is_question" is false, leave "question" and "answer" empty.''';
}

class _AnswerDecision {
  const _AnswerDecision({
    required this.isQuestion,
    required this.question,
    required this.answer,
    required this.basis,
    required this.confidence,
  });

  final bool isQuestion;
  final String question;
  final String answer;
  final String basis;
  final double confidence;
}
