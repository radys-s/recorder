import '../core/constants.dart';
import '../core/logging.dart';
import 'answer_source.dart';
import 'json_extract.dart';
import 'llm_provider.dart';

/// An answer found on the web, with the pages it came from.
class WebAnswer {
  const WebAnswer({required this.answer, required this.sources});

  final String answer;
  final List<AnswerSource> sources;
}

/// The second hop of live answering: take the question somebody asked in the
/// room and go and look it up.
///
/// Runs on Groq's agentic model, which performs the search server-side inside
/// an ordinary chat completion. That is what keeps the app's BYOK promise —
/// one key, the user's own Groq key, no second provider and no second signup.
///
/// **Only the question leaves the device.** Not the transcript, not the
/// surrounding context, not the meeting title. The first call in
/// [LiveAnswerService] has already distilled the passage down to a single
/// question sentence, so this is a property of the flow rather than a rule
/// this class has to enforce — but it is the whole reason the feature is off
/// by default, and it is what the Settings copy promises.
class WebAnswerService {
  WebAnswerService(this._llm);

  static const _tag = 'ai.answers.web';

  final LlmProvider _llm;

  /// Null on any failure at all — a timeout, a network error, a reply with no
  /// answer in it. The caller then keeps the answer the first call produced,
  /// so the feature degrades to the app's previous behaviour instead of
  /// costing the user their card. See [_ask] for the one failure that gets a
  /// second attempt, and why the others do not.
  Future<WebAnswer?> lookUp(String question) async {
    if (question.trim().isEmpty) return null;

    try {
      final completion = await _ask(question.trim());

      // Plain text, not JSON. Every token this call spends on `{"answer":`
      // is a token the backend cannot spend on the pages it fetched, and the
      // ceiling those pages keep breaking is the whole difficulty here. The
      // structure bought nothing anyway: the sources come from the server's
      // own record of the search, not from anything the model writes.
      final raw = completion.content.trim();
      final decoded = raw.startsWith('{') ? extractJsonObject(raw) : null;
      final answer = stripTrailingLinks(
        (decoded == null ? raw : '${decoded['answer'] ?? ''}').trim(),
      );
      if (answer.isEmpty) {
        AppLog.d(_tag, 'web model returned no answer for "$question"');
        return null;
      }

      // What the backend actually retrieved beats what the model says it
      // retrieved: `executed_tools` is the server's own record of the search,
      // so a link taken from there cannot be a citation the model invented to
      // look thorough. The model's self-reported list is the fallback for when
      // that block is absent or shaped differently than expected.
      var sources = collectAnswerSources(completion.executedTools);
      if (sources.isEmpty && decoded != null) {
        sources = collectAnswerSources(decoded['sources']);
      }

      AppLog.d(
        _tag,
        'web answer for "$question": ${answer.length} chars, '
        '${sources.length} source(s), '
        '${completion.executedTools.length} server-side tool call(s)',
      );

      // No server-side tool call means the model answered from its own
      // training data and never went near a search index. The answer may well
      // be fine, but the caller would badge it „Z internetu" — and a badge
      // claiming a source that was never consulted is worse than no badge.
      // The first call already produced a general-knowledge answer with the
      // honest label on it, so hand back nothing and let it stand.
      if (completion.executedTools.isEmpty) {
        AppLog.d(_tag, 'no search was run for "$question"; not claiming web');
        return null;
      }
      return WebAnswer(answer: answer, sources: sources);
    } catch (e, st) {
      // Deliberately swallowed, like every other failure in this feature: the
      // meeting is still being recorded, and an error banner about an answer
      // the user is not looking at would be worse than silence.
      AppLog.e(_tag, 'web lookup failed for "$question"', e, st);
      return null;
    }
  }

  /// The call itself, re-tossed for as long as [kWebRetryBudget] allows when —
  /// and only when — it failed in the way that is worth re-tossing.
  ///
  /// `groq/compound-mini` runs on `openai/gpt-oss-120b`, and on this free tier
  /// that model is capped at **8 000 tokens per minute**. Groq measures a
  /// single request against that same number, so a call is rejected with
  /// `413 request_too_large` as soon as the pages the backend's own search
  /// fetched push it past 8 000 — which is why the failure is a coin flip
  /// rather than a bug: which pages it opens differs run to run, and a probe
  /// measured roughly one call in three getting through. Re-tossing is
  /// affordable because the rejection arrives in four or five seconds, so
  /// [kWebRetryBudget] buys about three attempts and never delays the card by
  /// more than it says.
  ///
  /// A `429` is the same wall seen from the other side: the request fits under
  /// 8 000 on its own, but not on top of what this minute already spent. It
  /// differs in one useful way — it names the wait, and that wait has been as
  /// short as nine seconds. So it is retried too, but only after sleeping for
  /// as long as Groq asked, and only when that sleep still leaves time inside
  /// the budget. A `429` whose wait is 48 seconds ends the attempt, which is
  /// what M15's rule wants: the room has moved on by then.
  ///
  /// Anything else — a bad key, a retired model id, no connectivity — is not a
  /// coin flip and is handed straight back.
  Future<LlmCompletion> _ask(String question) async {
    final deadline = DateTime.now().add(kWebRetryBudget);
    var attempt = 0;

    while (true) {
      attempt++;
      try {
        return await _call(question);
      } on AiTransientException catch (e) {
        final wait = switch (e.statusCode) {
          413 => Duration.zero,
          429 => webRetryAfter(e.message),
          _ => null,
        };
        if (wait == null) rethrow;
        if (!DateTime.now().add(wait).isBefore(deadline)) rethrow;

        AppLog.d(
          _tag,
          'attempt $attempt hit the ${e.statusCode} ceiling; tossing again'
          '${wait == Duration.zero ? '' : ' in ${wait.inMilliseconds}ms'}',
        );
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
    }
  }

  Future<LlmCompletion> _call(String question) => _llm.completeDetailed(
        model: kGroqWebAnswerModel,
        messages: [
          LlmMessage.system(_systemPrompt),
          LlmMessage.user(question),
        ],
        temperature: 0.2,
        // Three sentences never needed 1 200, and every token asked for
        // here is counted against the same 8 000 the fetched pages have
        // to fit inside.
        maxTokens: 400,
        timeout: kWebAnswerTimeout,
      );

  /// English instructions, output in the question's language — the same split
  /// the notes and answer prompts use, and for the same reason: instruction
  /// following is steadier in English, and the output language is pinned by
  /// its own rule rather than by whichever language the rules happen to be in.
  ///
  /// Deliberately short. The longer version of this prompt said the same
  /// things at three times the length, and on a call whose whole difficulty is
  /// an 8 000-token ceiling shared with the pages the backend fetches, 200
  /// words of instructions is 200 words of a page that then did not fit.
  ///
  /// The register rules are the answer prompt's, restated, because this reply
  /// lands on the same card and must not read as a different app talking.
  static const String _systemPrompt = '''
Somebody asked this out loud in a meeting. Search the web and answer it.

Always search, even when you are sure you already know the answer. A rate, a
price or a date you remember is exactly the kind of fact that has moved since,
and this answer is shown with a badge saying it came from the internet.

Answer in the language the question is written in, in one to three plain
sentences with verbs. No bullets, no headings, no preamble, no repeating the
question back. Give the number, the name or the date whenever there is one, and
say how current it is. Never mention your own searching — "podle vyhledávání",
"našel jsem" must not appear. Put no citation anywhere in the answer: no square
brackets, no site names, no retrieval dates, and no URLs — not inside the
sentences and not appended underneath them. The pages you used are listed under
your answer as links the reader can open, so a citation written into the text is
at best a duplicate and at worst names a page that is not in that list. If the
web does not settle it, say in one sentence what is known and what is not. Do
not guess and do not pad.''';
}

/// Removes a trailing block of bare links from an answer.
///
/// The prompt asks for no citations twice over and the model writes them
/// anyway — first as `[Site 2026-09-04]` brackets, then, once those were
/// forbidden, as raw URLs pasted under the sentences. Both name pages that are
/// not necessarily among the three chips shown below the card, which is the
/// whole objection: a link the reader cannot check against the source list is
/// worse than no link. A prompt is a request; this is the guarantee.
///
/// Only *trailing* lines are dropped, and only ones that are nothing but a
/// link. A URL the answer genuinely talks about mid-sentence stays.
String stripTrailingLinks(String answer) {
  final lines = answer.split('\n');
  var end = lines.length;
  while (end > 0) {
    final line = lines[end - 1].trim();
    if (line.isEmpty || _bareLink.hasMatch(line)) {
      end--;
    } else {
      break;
    }
  }
  return lines.take(end).join('\n').trim();
}

/// A line holding a link and nothing else — optionally bulleted, optionally
/// wrapped in the punctuation models like to put around one.
final RegExp _bareLink =
    RegExp(r'^[-*•\s]*[<\[(]?https?://\S+?[>\])]?[.,;]?$');

/// The wait a `429` asks for, read out of the message Groq writes into the
/// body: *"Please try again in 9.375s"*.
///
/// Parsing prose is not how one would choose to learn this, but the wait is
/// only there — `classifyGroqFailure` keeps the message and drops the headers.
/// A shape this cannot read falls back to five seconds, which is the right
/// order of magnitude for a limit that resets every minute and is bounded by
/// [kWebRetryBudget] anyway.
Duration webRetryAfter(String message) {
  final match = RegExp(r'try again in ([0-9.]+)s').firstMatch(message);
  final seconds = double.tryParse(match?.group(1) ?? '');
  if (seconds == null) return const Duration(seconds: 5);
  return Duration(milliseconds: (seconds * 1000).ceil());
}
