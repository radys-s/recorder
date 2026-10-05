import 'dart:math';

/// Turns a clean sentence into what a worse speech recogniser would write:
/// no question mark, no capitals, no diacritics, a filler in front, a word
/// swallowed. Seeded, so a failing case reproduces.
///
/// Each transform is one thing a real Whisper / phone-call / video transcript
/// does; [variants] stacks them from mild to worst.
class Degrader {
  Degrader(int seed) : _random = Random(seed);

  final Random _random;

  static const _fold = {
    'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'í': 'i', 'ň': 'n',
    'ó': 'o', 'ř': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y',
    'ž': 'z', //
    'Á': 'A', 'Č': 'C', 'Ď': 'D', 'É': 'E', 'Ě': 'E', 'Í': 'I', 'Ň': 'N',
    'Ó': 'O', 'Ř': 'R', 'Š': 'S', 'Ť': 'T', 'Ú': 'U', 'Ů': 'U', 'Ý': 'Y',
    'Ž': 'Z',
  };

  static const _fillers = ['ehm', 'no', 'tak', 'jako', 'prostě', 'hele'];

  /// The question mark Whisper so often replaces with a full stop.
  String qmarkToDot(String s) => s.replaceAll('?', '.');

  String noPunctuation(String s) => s.replaceAll(RegExp(r'[.,?!…;:]'), '');

  String lower(String s) => s.toLowerCase();

  String noDiacritics(String s) => s.split('').map((c) => _fold[c] ?? c).join();

  /// A filler or two in front: speech has them, written text does not.
  String filler(String s) {
    final f = _fillers[_random.nextInt(_fillers.length)];
    return '${_random.nextBool() ? '$f ' : '$f, '}${_lowerFirst(s)}';
  }

  /// One word swallowed, never the first (a recogniser rarely drops the start
  /// of a sentence) and only from sentences long enough to survive it.
  String dropWord(String s) {
    final words = s.split(' ');
    if (words.length < 4) return s;
    words.removeAt(1 + _random.nextInt(words.length - 1));
    return words.join(' ');
  }

  /// A stutter: the first word said twice.
  String stutter(String s) {
    final i = s.indexOf(' ');
    if (i < 0) return s;
    return '${s.substring(0, i)} ${_lowerFirst(s)}';
  }

  /// A sentence cut off in the middle: a chunk boundary through it.
  String truncate(String s) {
    final words = s.split(' ');
    if (words.length < 5) return s;
    return words.sublist(0, words.length - 1).join(' ');
  }

  String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  /// Named variants, mildest first.
  Map<String, String Function(String)> get variants => {
    'čistý': (s) => s,
    '? → .': qmarkToDot,
    'bez interpunkce': noPunctuation,
    'malá písmena': (s) => lower(qmarkToDot(s)),
    'bez diakritiky': (s) => noDiacritics(qmarkToDot(s)),
    'vše dohromady': (s) => noDiacritics(lower(noPunctuation(s))),
    'výplň + ? → .': (s) => filler(qmarkToDot(s)),
    'chybí slovo': (s) => dropWord(qmarkToDot(s)),
    'koktání': (s) => stutter(qmarkToDot(s)),
    'useknuté': (s) => truncate(qmarkToDot(s)),
    'nejhorší': (s) =>
        noDiacritics(lower(noPunctuation(filler(dropWord(stutter(s)))))),
  };
}
