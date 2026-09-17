import 'transcript_sanitizer.dart';

/// A word the transcription keeps getting wrong: it writes [heard], the
/// lesson means [term]. Either side may be several words.
typedef TermCorrection = ({String heard, String term});

/// The corrected text and which of the pairs actually changed something.
typedef TermCorrectionResult = ({String text, Set<int> applied});

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// Replaces every whole-word occurrence of a pair's `heard` with its `term`.
///
/// Words are compared without case and diacritics, so a correction learned
/// from „prosko" also fixes „Prosko" and „Prosko," — but only whole words: a
/// pair never rewrites the middle of a longer word. Between the words of a
/// multi-word `heard` anything that is not a letter counts as a gap, so
/// „Božena  Němcová" and „Božena-Němcová" match „Božena Němcová".
///
/// One left-to-right pass, longest `heard` first at each position, so a
/// replacement is never corrected again by another pair. A capital letter the
/// original started with stays; a capital the term starts with (a name) also
/// stays.
TermCorrectionResult applyTermCorrections(
  String text,
  List<TermCorrection> pairs,
) {
  if (text.isEmpty || pairs.isEmpty) return (text: text, applied: const {});

  final prepared = <({int index, List<String> keys, String term})>[
    for (var i = 0; i < pairs.length; i++)
      if (_keys(pairs[i].heard) case final keys when keys.isNotEmpty)
        (index: i, keys: keys, term: pairs[i].term.trim()),
  ]..sort((a, b) => b.keys.length.compareTo(a.keys.length));
  if (prepared.isEmpty) return (text: text, applied: const {});

  final words = _word.allMatches(text).toList();
  final keys = [for (final w in words) normalizeForArtifactMatch(w[0]!)];

  final out = StringBuffer();
  final applied = <int>{};
  var cursor = 0;
  var i = 0;
  while (i < words.length) {
    final match = _matchAt(prepared, keys, words, text, i);
    if (match == null) {
      i++;
      continue;
    }
    final first = words[i];
    final last = words[i + match.keys.length - 1];
    final original = text.substring(first.start, last.end);
    final replacement = _keepCapital(original, match.term);
    if (replacement != original) {
      out
        ..write(text.substring(cursor, first.start))
        ..write(replacement);
      cursor = last.end;
      applied.add(match.index);
    }
    i += match.keys.length;
  }
  if (applied.isEmpty) return (text: text, applied: const {});
  out.write(text.substring(cursor));
  return (text: out.toString(), applied: applied);
}

({int index, List<String> keys, String term})? _matchAt(
  List<({int index, List<String> keys, String term})> prepared,
  List<String> keys,
  List<RegExpMatch> words,
  String text,
  int at,
) {
  for (final pair in prepared) {
    final n = pair.keys.length;
    if (at + n > keys.length) continue;
    var ok = true;
    for (var k = 0; k < n && ok; k++) {
      ok = keys[at + k] == pair.keys[k];
      // A sentence end between two words breaks a multi-word match.
      if (ok && k > 0) {
        final gap = text.substring(words[at + k - 1].end, words[at + k].start);
        ok = !gap.contains(RegExp(r'[.!?…\n]'));
      }
    }
    if (ok) return pair;
  }
  return null;
}

/// Folded words of [phrase]; a word folding into several (rare symbols) is
/// kept whole so the count still lines up with the text's words.
List<String> _keys(String phrase) =>
    [for (final w in _word.allMatches(phrase)) normalizeForArtifactMatch(w[0]!)]
        .where((k) => k.isNotEmpty)
        .toList();

String _keepCapital(String original, String term) {
  if (term.isEmpty || original.isEmpty) return term;
  final o = original[0];
  final t = term[0];
  if (o != o.toLowerCase() && t == t.toLowerCase()) {
    return t.toUpperCase() + term.substring(1);
  }
  return term;
}
