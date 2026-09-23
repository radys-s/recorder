import '../core/constants.dart';
import '../core/logging.dart';
import 'answer_source.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';

/// An answer grounded in pages retrieved for the question.
class WebAnswer {
  const WebAnswer({required this.answer, required this.sources});

  final String answer;
  final List<AnswerSource> sources;
}

/// The second hop of live answering: look up an unresolved question.
///
/// Only the question leaves the device. It is intentionally sent to Gemini's
/// Google Search grounding rather than the retired Groq Compound model: the
/// grounding response names the pages it used, which is the evidence required
/// before the UI may say "Z internetu". If grounding is unavailable, the
/// caller keeps its already-produced, honestly labelled model answer.
class WebAnswerService {
  WebAnswerService(this._gemini, {required this.hasGeminiKey});

  static const _tag = 'ai.answers.web';

  final GeminiProvider _gemini;
  final Future<bool> Function() hasGeminiKey;

  /// Never throws. A web answer is an enhancement to a live answer, not a
  /// reason to make a card disappear when the student is offline or a free
  /// quota is busy.
  Future<WebAnswer?> lookUp(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return null;

    try {
      if (!await hasGeminiKey()) {
        AppLog.d(_tag, 'Gemini key absent; keeping the non-web answer');
        return null;
      }

      final completion = await _gemini.generate(
        model: kGeminiModel,
        messages: [
          const LlmMessage.system(_systemPrompt),
          LlmMessage.user(trimmed),
        ],
        search: true,
        maxTokens: 400,
        timeout: kWebAnswerTimeout,
      );
      final answer = stripTrailingLinks(completion.content);
      if (answer.isEmpty) {
        AppLog.d(_tag, 'grounded model returned no answer for "$trimmed"');
        return null;
      }

      // A search request can be downgraded by a model or provider. That reply
      // may still be useful as general knowledge, but it is not evidence for a
      // web badge. Require both the grounding flag and at least one validated
      // page before promoting it over the first answer.
      if (!completion.grounded || completion.sources.isEmpty) {
        AppLog.d(
          _tag,
          'no verified grounding for "$trimmed"; not claiming web',
        );
        return null;
      }

      AppLog.d(
        _tag,
        'grounded answer for "$trimmed": ${answer.length} chars, '
        '${completion.sources.length} source(s)',
      );
      return WebAnswer(answer: answer, sources: completion.sources);
    } catch (e, st) {
      AppLog.e(_tag, 'web lookup failed for "$trimmed"', e, st);
      return null;
    }
  }

  static const String _systemPrompt = '''
Somebody asked this out loud in a class. Search the web and answer it.

Answer in the language of the question in one to three plain sentences. Give a
number, name or date when one exists and state how current it is. No bullets,
headings, preamble, repetition of the question, citations, site names, dates of
retrieval or URLs in the answer. Never mention searching. If the web does not
settle it, say briefly what is known and what is not. Do not guess or pad.''';
}

/// Removes a trailing block of bare links a model appended despite the prompt.
/// A genuine URL in the middle of an explanatory sentence remains untouched.
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

final RegExp _bareLink = RegExp(r'^[-*•\s]*[<\[(]?https?://\S+?[>\])]?[.,;]?$');
