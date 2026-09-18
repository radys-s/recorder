import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/daos/subjects_dao.dart';
import '../data/db/tables/subject_terms_table.dart';
import '../stt/transcript_sanitizer.dart' show normalizeForArtifactMatch;
import 'json_extract.dart';
import 'llm_provider.dart';

/// A term and one way Czech speech recognition plausibly writes it.
typedef TermAlias = ({String term, String heard});

/// How many terms one request asks about.
const int kAliasTermsPerRequest = 60;

/// How many aliases a single term may contribute.
const int kAliasesPerTerm = 3;

/// Teaches the subject's vocabulary how it gets misheard.
///
/// English and abbreviated terms are what Czech Whisper fails on hardest —
/// „VLAN" comes back as „vílan", „OSPF" as „ó es pé ef". One call per subject
/// turns the subject's own words into `heard` rows, which the deterministic
/// [applyTermCorrections] then fixes on every chunk for free, with no AI in
/// the lesson at all.
class TermAliasService {
  TermAliasService(this._subjects, this._llm);

  static const _tag = 'ai.terms.alias';

  final SubjectsDao _subjects;
  final LlmProvider _llm;
  final _inFlight = <int>{};

  /// How many alias rows were written. Never throws.
  Future<int> generate(int subjectId) async {
    if (!_inFlight.add(subjectId)) return 0;
    try {
      final rows = await _subjects.terms(subjectId);
      final topics = await _subjects.topics(subjectId);
      final known = <String>{};
      final words = <String>[];
      void offer(String word) {
        final w = word.trim();
        final key = normalizeForArtifactMatch(w);
        if (w.isEmpty || key.isEmpty || !known.add(key)) return;
        words.add(w);
      }

      // Terms that already have a `heard` form are the ones this is for; the
      // plan's own vocabulary is where the foreign words usually live.
      for (final t in rows) {
        if (t.heard == null) offer(t.term);
      }
      for (final t in topics) {
        for (final term in (t.terms ?? '').split(',')) {
          offer(term);
        }
      }
      if (words.isEmpty) return 0;

      final taken = words.take(kAliasTermsPerRequest).toList();
      final raw = await _llm.complete(
        model: kGroqNotesModel,
        messages: [
          const LlmMessage.system(_systemPrompt),
          LlmMessage.user(taken.join('\n')),
        ],
        temperature: 0.2,
        maxTokens: 3000,
        jsonMode: true,
        timeout: kCardDigestTimeout,
      );

      var written = 0;
      for (final alias in parseTermAliases(raw, terms: taken)) {
        try {
          await _subjects.addTerm(
            subjectId,
            alias.term,
            heard: alias.heard,
            source: TermSource.alias,
          );
          written++;
        } catch (e) {
          AppLog.d(_tag, 'skipped ${alias.heard}: $e');
        }
      }
      AppLog.d(_tag, 'subject $subjectId: $written aliases');
      return written;
    } catch (e, st) {
      AppLog.e(_tag, 'subject $subjectId failed', e, st);
      return 0;
    } finally {
      _inFlight.remove(subjectId);
    }
  }

  static const String _systemPrompt = '''
Czech speech recognition writes foreign words and abbreviations the way they
sound in Czech. Given a lesson's vocabulary, say how each word most likely
comes out wrong.

Reply with one JSON object and nothing else:
{"aliases": [{"term": "VLAN", "heard": ["vílan", "v lan"]}, ...]}

- Only for words that are English, an abbreviation, or otherwise foreign.
  Skip ordinary Czech words entirely — they are already written right.
- At most $kAliasesPerTerm forms per word, each the whole word as a Czech
  recogniser would write it, spelled out when it is read letter by letter.
- "term" must be copied exactly from the list.
- Never give a form that is an ordinary Czech word on its own.''';
}

/// The aliases in a reply, keeping only the ones [acceptAlias] allows.
///
/// [terms] is the list that was asked about; a "term" the model made up is
/// dropped, so a hallucinated pair can never rewrite the transcript.
List<TermAlias> parseTermAliases(String raw, {Iterable<String> terms = const []}) {
  final decoded = extractJsonObject(raw);
  final list = decoded?['aliases'];
  if (list is! List) return const [];
  final allowed = {
    for (final t in terms) normalizeForArtifactMatch(t): t.trim(),
  };
  final out = <TermAlias>[];
  final seen = <String>{};
  for (final item in list) {
    if (item is! Map) continue;
    final rawTerm = item['term'];
    if (rawTerm is! String) continue;
    final term = allowed.isEmpty
        ? rawTerm.trim()
        : allowed[normalizeForArtifactMatch(rawTerm)];
    if (term == null || term.isEmpty) continue;
    final heardValue = item['heard'];
    final forms = switch (heardValue) {
      final List<Object?> l => [
        for (final h in l)
          if (h is String) h,
      ],
      final String s => [s],
      _ => const <String>[],
    };
    var kept = 0;
    for (final form in forms) {
      if (kept >= kAliasesPerTerm) break;
      final heard = form.trim();
      if (!acceptAlias(heard, term: term)) continue;
      if (!seen.add(normalizeForArtifactMatch(heard))) continue;
      out.add((term: term, heard: heard));
      kept++;
    }
  }
  return out;
}

/// Whether [heard] is safe to rewrite into [term] on every chunk.
///
/// This is the one feature that can corrupt text the teacher really said, so
/// the guard is the promise and the prompt is only the request: a form has to
/// be long enough or multi-word to be unlikely by accident, must differ from
/// the term, and must not be an ordinary Czech word.
bool acceptAlias(String heard, {required String term}) {
  final text = heard.trim();
  if (text.isEmpty || text.length > 80) return false;
  final folded = normalizeForArtifactMatch(text);
  if (folded.isEmpty) return false;
  if (folded == normalizeForArtifactMatch(term)) return false;
  final parts = folded.split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.length < 2 && folded.length < 4) return false;
  for (final word in parts) {
    if (kCzechStopWords.contains(word)) return false;
  }
  return true;
}

/// Czech words common enough that rewriting one would be a bug, whatever the
/// model claims to have heard. Folded, so they match the alias check.
const Set<String> kCzechStopWords = {
  'ale',
  'ano',
  'asi',
  'aby',
  'akorat',
  'bude',
  'budou',
  'byla',
  'bylo',
  'byli',
  'byt',
  'celkem',
  'coz',
  'dal',
  'dale',
  'dobre',
  'hodne',
  'jak',
  'jako',
  'jde',
  'jeho',
  'jeji',
  'jen',
  'jeste',
  'jsem',
  'jsi',
  'jsme',
  'jsou',
  'jste',
  'kde',
  'kdy',
  'kdyz',
  'ktere',
  'kteri',
  'ktery',
  'ma',
  'mame',
  'mate',
  'mel',
  'mit',
  'muze',
  'nas',
  'nebo',
  'neni',
  'ono',
  'pak',
  'podle',
  'pouze',
  'prave',
  'pred',
  'pres',
  'pri',
  'proc',
  'proto',
  'protoze',
  'prvni',
  'sem',
  'tak',
  'take',
  'tam',
  'tedy',
  'ten',
  'tim',
  'tohle',
  'toho',
  'tom',
  'tomu',
  'tuto',
  'tyto',
  'vsak',
  'vsechno',
  'zase',
  'zde',
  'zpet',
};
