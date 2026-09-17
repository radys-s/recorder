import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/daos/subjects_dao.dart';
import '../data/db/tables/subject_terms_table.dart';
import 'json_extract.dart';
import 'llm_provider.dart';

/// A card's short summary and its spelling-sensitive terms.
class CardDigest {
  const CardDigest({required this.summary, required this.keywords});

  final String summary;

  /// Comma-separated, the stored form the glossary already reads.
  final String keywords;
}

/// Writes `summary` and `keywords` for cards that have none.
///
/// The summary is what a pinned card contributes first when the context
/// budget is tight; the keywords go to Whisper so names like Proško come back
/// spelled right. One cheap call per card, made when the card is saved —
/// never during a lesson. Gemini's lite model when that key exists, otherwise
/// Groq, which is fine outside a lesson where nothing else competes for its
/// per-minute tokens.
class CardDigestService {
  CardDigestService(
    this._cards, {
    required this._groq,
    this._gemini,
    this._hasGeminiKey,
  });

  static const _tag = 'ai.cards.digest';

  final SubjectsDao _cards;
  final LlmProvider _groq;
  final LlmProvider? _gemini;
  final Future<bool> Function()? _hasGeminiKey;
  final _inFlight = <int>{};

  /// Digests every card of [subjectId] that lacks a summary, newest edit
  /// first, one at a time. Never throws.
  Future<void> digestMissing(int subjectId) async {
    try {
      final cards = await _cards.cards(subjectId);
      for (final card in cards) {
        if (card.summary == null && card.content.trim().isNotEmpty) {
          await digest(card.id);
        }
      }
    } catch (e, st) {
      AppLog.e(_tag, 'subject $subjectId: digest pass failed', e, st);
    }
  }

  /// True when a digest was written. Never throws.
  Future<bool> digest(int cardId) async {
    if (!_inFlight.add(cardId)) return false;
    try {
      final card = await _cards.card(cardId);
      if (card == null || card.summary != null) return false;
      final content = card.content.trim();
      if (content.isEmpty) return false;

      final useGemini = _gemini != null && await _geminiAvailable();
      final llm = useGemini ? _gemini : _groq;
      final limit = useGemini ? kDigestGeminiChars : kDigestGroqChars;
      final raw = await llm.complete(
        model: useGemini ? kGeminiLiteModel : kGroqNotesModel,
        messages: [
          const LlmMessage.system(_systemPrompt),
          LlmMessage.user(
            'Title: ${card.title}\n\n'
            '${content.length <= limit ? content : content.substring(0, limit)}',
          ),
        ],
        temperature: 0.2,
        // Reasoning counts against the cap on both backends.
        maxTokens: useGemini ? 2000 : 1500,
        jsonMode: true,
        timeout: kCardDigestTimeout,
      );

      final parsed = parseCardDigest(raw);
      if (parsed == null) {
        AppLog.d(_tag, 'card $cardId: reply had no summary');
        return false;
      }
      // Written only if the content is still what was summarised.
      final written = await _cards.setCardDigest(
        cardId,
        content: card.content,
        summary: parsed.summary,
        keywords: parsed.keywords,
      );
      AppLog.d(
        _tag,
        'card $cardId digested on ${useGemini ? 'Gemini' : 'Groq'}: $written',
      );
      if (written && parsed.keywords.isNotEmpty) {
        // The card's names become the subject's vocabulary, so transcription
        // spells them right even in lessons that do not pin this card.
        await _cards.addTerms(
          card.subjectId,
          parsed.keywords.split(','),
          TermSource.card,
        );
      }
      return written;
    } catch (e, st) {
      AppLog.e(_tag, 'card $cardId: digest failed', e, st);
      return false;
    } finally {
      _inFlight.remove(cardId);
    }
  }

  Future<bool> _geminiAvailable() async {
    try {
      return await _hasGeminiKey?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  static const String _systemPrompt = '''
A student prepared this study card for use in class. Write a digest of it.

Reply with one JSON object and nothing else:
{"summary": "...", "keywords": ["...", "..."]}

"summary": at most 600 characters, in the card's own language. The facts most
likely to be asked about: what or who it is, author and period, type or genre,
the main terms and relations. Plain sentences, no preamble, nothing that is not
in the card.

"keywords": up to 15 proper nouns and specialist terms exactly as spelled in
the card — names of people, characters, places, works, technical terms — the
words a speech recogniser would most likely misspell. No common words.''';
}

/// The digest in a reply, or null when it has no summary.
CardDigest? parseCardDigest(String raw) {
  final decoded = extractJsonObject(raw);
  if (decoded == null) return null;

  final summary = _clip(
    '${decoded['summary'] is String ? decoded['summary'] : ''}'.trim(),
    kCardSummaryMaxChars,
  );
  if (summary.isEmpty) return null;

  final rawKeywords = decoded['keywords'];
  final candidates = rawKeywords is List
      ? [
          for (final k in rawKeywords)
            if (k is String) k,
        ]
      : rawKeywords is String
      ? rawKeywords.split(',')
      : const <String>[];

  final seen = <String>{};
  final keywords = <String>[];
  for (final candidate in candidates) {
    final keyword = candidate.trim().replaceAll(',', ' ');
    if (keyword.isEmpty || keyword.length > 40) continue;
    if (!seen.add(keyword.toLowerCase())) continue;
    keywords.add(keyword);
    if (keywords.length >= 20) break;
  }

  return CardDigest(summary: summary, keywords: keywords.join(', '));
}

/// Cuts on a word boundary and marks the cut.
String _clip(String text, int max) {
  if (text.length <= max) return text;
  final cut = text.substring(0, max - 1);
  final space = cut.lastIndexOf(' ');
  return '${(space > max ~/ 2 ? cut.substring(0, space) : cut).trimRight()}…';
}
