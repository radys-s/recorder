import 'package:dio/dio.dart' show CancelToken;

import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../core/logging.dart';
import 'answer_source.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';
import 'photo_text_service.dart';
import 'web_answer_service.dart';

/// What „Dohledat" found: card text and the pages it came from.
class CardLookup {
  const CardLookup({
    required this.content,
    required this.sources,
    this.viaGemini = true,
    this.geminiProblem,
    this.truncated = false,
    this.grounded = true,
  });

  final String content;
  final List<AnswerSource> sources;

  /// False for the short Groq fallback, which the editor says out loud.
  final bool viaGemini;

  /// Why Gemini was not used although a key is set — shown with the result.
  final String? geminiProblem;

  /// Gemini ran out of output tokens; the card may end mid-section.
  final bool truncated;

  /// Gemini answered without Google Search (the model refused the tool).
  final bool grounded;
}

/// Looks a topic up on the web and writes it as a study card.
///
/// With a Gemini key: Gemini with Google Search and a fixed structure (a work
/// of literature gets the Czech school analysis, anything else an overview).
/// Without one: Groq's compound search, which only manages a few sentences
/// and fails more often on this tier — better than a button that does nothing.
///
/// Only the typed topic and the subject name leave the device.
class CardLookupService {
  CardLookupService({
    required this._gemini,
    required this._hasGeminiKey,
    required this._web,
  });

  static const _tag = 'ai.cards.lookup';

  final GeminiProvider _gemini;
  final Future<bool> Function() _hasGeminiKey;
  final WebAnswerService _web;

  /// Throws [AiException] with a message [geminiFailureText] can show.
  Future<CardLookup> lookUp(
    String query, {
    String? subjectName,
    CancelToken? cancelToken,
  }) async {
    final topic = query.trim();
    if (topic.isEmpty) throw ArgumentError.value(query, 'query', 'blank');

    final hasKey = await _geminiAvailable();
    AiException? geminiError;
    if (hasKey) {
      try {
        final result = await _gemini.generate(
          model: kGeminiModel,
          messages: [
            const LlmMessage.system(_prompt),
            LlmMessage.user(subjectName == null
                ? 'Topic: $topic'
                : 'School subject: $subjectName\nTopic: $topic'),
          ],
          search: true,
          maxTokens: 12000,
          timeout: kCardLookupTimeout,
          cancelToken: cancelToken,
        );
        final content = stripTrailingLinks(cleanModelText(result.content));
        if (content.isEmpty) {
          throw const AiPermanentException('Dohledání nic nevrátilo.');
        }
        AppLog.d(_tag,
            'looked up on Gemini: ${content.length} chars, ${result.sources.length} source(s)');
        return CardLookup(
          content: content,
          sources: result.sources,
          truncated: result.truncated,
          grounded: result.grounded,
        );
      } on AiException catch (e) {
        // A wrong key is the user's to fix, and a cancelled lookup was meant
        // to stop; anything else is worth a second route.
        if (e.kind == GeminiErrorKind.badKey || cancelToken?.isCancelled == true) {
          rethrow;
        }
        AppLog.e(_tag, 'Gemini lookup failed, trying Groq', e);
        geminiError = e;
      }
    }

    final web = await _web.lookUp(
      subjectName == null ? topic : '$topic ($subjectName)',
    );
    if (web == null) {
      if (geminiError != null) throw geminiError;
      throw const AiTransientException(
        'Dohledání se nepovedlo. S Gemini klíčem v Nastavení to jde spolehlivěji.',
      );
    }
    return CardLookup(
      content: web.answer,
      sources: web.sources,
      viaGemini: false,
      geminiProblem: geminiError == null ? null : geminiFailureText(geminiError),
    );
  }

  Future<bool> _geminiAvailable() async {
    try {
      return await _hasGeminiKey();
    } catch (_) {
      return false;
    }
  }

  static const String _prompt = '''
A student is preparing a study card for school. Search the web and write the
card about the topic. Write in Czech unless the topic is clearly written in
another language. Plain text only: short heading lines ending with a colon,
"- " bullets, short sentences. No Markdown symbols, no citations, no URLs, no
preamble, nothing about your searching.

If the topic is a work of literature (or its author together with a work), use
exactly these headings, in this order, leaving out one only when nothing
reliable is known:
Autor:
Období a literární směr:
Literární druh:
Literární žánr:
Děj:
Postavy:
Témata a motivy:
Jazykové prostředky:
Proč je dílo důležité:

Otherwise use:
Přehled:
Klíčová fakta:
Pojmy:

Be accurate and concrete: names, dates, terms a teacher would ask about. Keep
it to what fits on one or two pages of a notebook.''';
}

/// [existing] followed by the new links, de-duplicated by site and capped.
List<AnswerSource> mergeCardSources(
  List<AnswerSource> existing,
  List<AnswerSource> added, {
  int max = kMaxCardSources,
}) {
  final merged = <AnswerSource>[];
  for (final source in [...existing, ...added]) {
    if (merged.length >= max) break;
    if (merged.any((s) => s.domain == source.domain)) continue;
    merged.add(source);
  }
  return merged;
}
