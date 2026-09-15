import 'transcript_sanitizer.dart';

/// How much of Whisper's prompt the glossary may take. The transcript tail
/// keeps its own 200 characters after it.
const int kGlossaryMaxChars = 120;

/// Names and terms from the lesson's pinned cards, for Whisper's prompt.
///
/// Whisper spells a word it has just seen in the prompt far better — and the
/// words answers depend on (Proško, Viktorka) are exactly the ones it would
/// otherwise mangle. Order: the card's keywords, its title, then capitalised
/// words from inside sentences, most frequent first.
String? buildWhisperGlossary(
  Iterable<({String title, String content, String? keywords})> cards, {
  int maxChars = kGlossaryMaxChars,
}) {
  final terms = <String>[];
  final seen = <String>{};
  void add(String term) {
    final t = term.trim();
    final key = normalizeForArtifactMatch(t);
    if (key.length < 3 || !seen.add(key)) return;
    terms.add(t);
  }

  final list = cards.toList();
  for (final card in list) {
    for (final k in (card.keywords ?? '').split(',')) {
      add(k);
    }
  }
  for (final card in list) {
    add(card.title);
  }

  final counts = <String, int>{};
  for (final card in list) {
    for (final name in _properNouns(card.content)) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  final names = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  names.forEach(add);

  final buffer = StringBuffer();
  for (final term in terms) {
    final extra = buffer.isEmpty ? term.length : term.length + 2;
    if (buffer.length + extra > maxChars) continue;
    if (buffer.isNotEmpty) buffer.write(', ');
    buffer.write(term);
  }
  return buffer.isEmpty ? null : buffer.toString();
}

final _word = RegExp(r'\p{L}+', unicode: true);

/// Capitalised words that do not open a sentence — names, mostly.
Iterable<String> _properNouns(String text) sync* {
  for (final match in _word.allMatches(text)) {
    final w = match.group(0)!;
    if (w.length < 3) continue;
    final first = w[0];
    if (first == first.toLowerCase() || w == w.toUpperCase()) continue;
    final before = text.substring(0, match.start).trimRight();
    if (before.isEmpty || '.!?…:\n"„'.contains(before[before.length - 1])) {
      continue;
    }
    yield w;
  }
}
