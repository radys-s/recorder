import '../../ai/llm_provider.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';

/// One request shape to try against the web-answer model.
class _Variant {
  const _Variant(this.name, this.systemPrompt, this.maxTokens);

  final String name;

  /// Null means no system message at all — the smallest request that can still
  /// ask the question.
  final String? systemPrompt;
  final int maxTokens;
}

/// Fires the same question at Groq's agentic model in several request shapes
/// and reports which ones come back.
///
/// It exists because the web hop fails with `413 request_too_large` and the
/// question is *whose* tokens are to blame. Groq measures that limit against
/// the single request — 70 000 on this tier — and the compound backend folds
/// the pages its own search fetched into it, so the request the app sends is
/// only part of the total. This probe varies the part the app controls (the
/// system prompt and the completion budget) while holding the question fixed.
///
/// If even [_Variant] `min` — no system prompt, a 300-token budget — fails
/// every time, then the fetched pages alone exceed the ceiling and no amount of
/// trimming on this side will help. That is a conclusion worth reaching
/// deliberately rather than by guessing.
///
/// Each variant runs [repeats] times, because the failure is a coin flip:
/// which pages the backend opens differs run to run, so a single observation
/// says nothing.
///
/// Debug builds only, reached from Settings → Diagnostika.
class WebAnswerProbe {
  const WebAnswerProbe(this._llm);

  static const _tag = 'ai.answers.probe';

  /// A question with a checkable, current answer that no model can hold in its
  /// training data, so the backend has to search to answer it at all — which
  /// is the condition that provokes the failure.
  static const question =
      'Jaká je aktuální základní úroková sazba České národní banky?';

  static const repeats = 3;

  static const _variants = <_Variant>[
    _Variant('min', null, 300),
    _Variant('short', 'Search the web and answer in one Czech sentence.', 400),
    _Variant('prod', _prodPrompt, 1200),
  ];

  /// A stand-in for the production system prompt, matched in length rather than
  /// copied, so the variant measures the cost of sending ~250 words of
  /// instructions without the two prompts drifting apart over time.
  static const _prodPrompt = '''
You are given one question that somebody asked out loud in a meeting. Search
the web and answer it. Always search, even for a question you are confident you
already know, because the answer is shown with a badge saying it came from the
internet. Answer in the language the question is written in, in one to three
plain sentences with verbs, with no bullets, no headings and no preamble. Give
the number, the name or the date whenever there is one, and say how current it
is. Never describe your own searching. If the web does not settle it, say in one
sentence what is known and what is not; do not guess and do not pad. List only
pages you actually used, at most three, each with the exact URL you retrieved,
and never invent or complete a URL. Reply with one JSON object and nothing else:
{"answer": "...", "sources": [{"title": "...", "url": "https://..."}]}''';

  final LlmProvider _llm;

  /// Returns one human-readable line per variant.
  Future<List<String>> run() async {
    final lines = <String>[];

    for (final variant in _variants) {
      var ok = 0;
      var searched = 0;
      final failures = <String>{};
      var totalMs = 0;

      for (var i = 0; i < repeats; i++) {
        final started = DateTime.now();
        try {
          final completion = await _llm.completeDetailed(
            model: kGroqWebAnswerModel,
            messages: [
              if (variant.systemPrompt != null)
                LlmMessage.system(variant.systemPrompt!),
              LlmMessage.user(question),
            ],
            temperature: 0.2,
            maxTokens: variant.maxTokens,
            timeout: kWebAnswerTimeout,
          );
          ok++;
          if (completion.executedTools.isNotEmpty) searched++;
          AppLog.d(_tag, '${variant.name} ok: ${completion.content}');
        } on AiException catch (e) {
          failures.add('${e.statusCode ?? '?'}');
          AppLog.d(_tag, '${variant.name} failed: $e');
        } catch (e) {
          failures.add(e.runtimeType.toString());
          AppLog.d(_tag, '${variant.name} failed: $e');
        }
        totalMs += DateTime.now().difference(started).inMilliseconds;
      }

      final line = '${variant.name} (${variant.maxTokens} t): '
          '$ok/$repeats ok, $searched hledalo'
          '${failures.isEmpty ? '' : ', chyby ${failures.join('/')}'}'
          ' — ${totalMs ~/ repeats}ms';
      lines.add(line);
      AppLog.d(_tag, line);
    }

    return lines;
  }
}
