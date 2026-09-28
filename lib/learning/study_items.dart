import '../ai/json_extract.dart';
import '../data/db/daos/study_cards_dao.dart';
import '../data/db/tables/study_cards_table.dart';
import '../stt/transcript_sanitizer.dart';

/// At most this many cards come out of one model call.
const int kMaxGeneratedStudyCards = 12;

final _bullet = RegExp(r'^[-•–*]\s+');

String _clean(String raw) =>
    raw.trim().replaceAll('**', '').replaceAll('#', '').trim();

bool _isHeading(String line) => _bullet.firstMatch(line) == null;

bool _startsWith(String line, String folded) =>
    normalizeForArtifactMatch(line).startsWith(folded);

/// Bullets under the heading that starts with [folded] (already folded).
List<String> _section(String notes, String folded) {
  final out = <String>[];
  var inSection = false;
  for (final raw in notes.split('\n')) {
    final line = _clean(raw);
    if (line.isEmpty) continue;
    if (_isHeading(line)) {
      inSection = _startsWith(line, folded);
      continue;
    }
    if (inSection) {
      final item = line.substring(_bullet.firstMatch(line)!.end).trim();
      if (item.isNotEmpty) out.add(item);
    }
  }
  return out;
}

/// „Klíčové pojmy" bullets written as `pojem – definice` become cards with
/// the term on the front and the definition on the back.
///
/// A bullet without a definition, or whose „term" reads like a sentence, is
/// left out: a card that asks nothing is worse than no card.
List<StudyItem> termCardsFromNotes(String notes) {
  final out = <StudyItem>[];
  for (final item in _section(notes, 'klicove pojmy')) {
    final split = RegExp(r'\s[–—-]\s|:\s').firstMatch(item);
    if (split == null) continue;
    final term = item.substring(0, split.start).trim();
    final definition = item.substring(split.end).trim();
    final words = term.split(RegExp(r'\s+')).length;
    if (term.length < 2 || term.length > 60 || words > 5) continue;
    if (definition.length < 3) continue;
    out.add(StudyItem(term, definition, StudySource.terms));
  }
  return out;
}

/// The „Co si zapamatovat" bullets, as written.
List<String> rememberBulletsFromNotes(String notes) =>
    _section(notes, 'co si zapamatovat');

/// Question–answer pairs from a model reply: `{"cards": [{"q", "a"}]}`.
/// Malformed items are skipped; a malformed reply gives nothing.
List<StudyItem> parseStudyPairs(String raw, StudySource source) {
  final list = extractJsonObject(raw)?['cards'];
  if (list is! List) return const [];
  final out = <StudyItem>[];
  final seen = <String>{};
  for (final item in list) {
    if (out.length == kMaxGeneratedStudyCards) break;
    if (item is! Map) continue;
    final q = item['q'], a = item['a'];
    if (q is! String || a is! String) continue;
    if (q.trim().isEmpty || a.trim().isEmpty) continue;
    if (!seen.add(StudyCardsDao.keyFor(q))) continue;
    out.add(StudyItem(q.trim(), a.trim(), source));
  }
  return out;
}
