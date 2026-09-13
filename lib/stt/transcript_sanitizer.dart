/// Removes Whisper's silence hallucinations from a transcript chunk.
///
/// Whisper was trained on a great deal of subtitled video, so when it is given
/// audio with no speech in it — a pause between sentences that happened to land
/// on a chunk boundary, a quiet stretch while someone reads — it does not
/// return an empty string. It returns the most likely thing to appear over
/// silence in its training data: a subtitler's credit, or a sign-off.
///
/// In English those artifacts are short ("you", "Thank you.") and are mostly
/// caught upstream by [kMinTranscribableDuration], which never uploads a chunk
/// under half a second. The Czech ones are full sentences — *"Titulky vytvořil
/// Jan Novák"*, *"Děkuji za pozornost."* — and arrive in chunks of a perfectly
/// normal length, so no duration guard can see them. Pinning the language makes
/// this *more* likely, not less: told the audio is Czech, Whisper loses the
/// option of returning nothing at all.
///
/// Getting this wrong in either direction matters, so the rules are
/// deliberately narrow:
///
///   * the whole text is an artifact  → drop everything,
///   * the *last* sentence is one     → drop that sentence,
///   * an artifact appears mid-text   → leave it alone.
///
/// The last rule is the important one. "Děkuji za pozornost" in the middle of a
/// transcript is almost certainly something a person in the room actually said,
/// and silently deleting it would be exactly the failure this whole feature
/// exists to prevent.
library;

/// Artifacts that only count when they are the entire sentence.
///
/// Written in normalised form: lowercase, diacritics folded, punctuation gone.
const List<String> _kExactArtifacts = [
  // Czech
  'dekuji za pozornost',
  'dekuji vam za pozornost',
  'dekujeme za pozornost',
  'dekuji za sledovani',
  'dekuju za pozornost',
  'odebirejte kanal',
  'titulky',
  // Sound-event tags, which arrive bare or in brackets ("[hudba]").
  'hudba',
  'potlesk',
  'smich',
  'music',
  'applause',
  'laughter',
  // English — 'auto' and 'en' are still selectable, and auto-detect can still
  // land on English for a chunk of silence.
  'you',
  'thank you',
  'thanks for watching',
  'thank you for watching',
  'please subscribe',
  'bye',
];

/// Artifacts that introduce a name or a source, so only the opening is fixed.
///
/// Kept separate from [_kExactArtifacts] on purpose: matching "you" as a prefix
/// would eat "You know what I mean", which is real speech.
const List<String> _kPrefixArtifacts = [
  // Czech
  'titulky vytvoril',
  'titulky pro vas vytvoril',
  'titulky pro vas pripravil',
  'preklad titulku',
  'titulky z portalu',
  'prepis a korektura',
  // English
  'subtitles by',
  'subtitles created by',
  'transcription by',
];

/// Returns [raw] with silence artifacts removed, or an empty string when the
/// whole response was one. Pure — no logging, no I/O — so it is unit-testable
/// and safe to call from anywhere.
String sanitizeTranscript(String raw) {
  // A bracketed sound tag is never speech, wherever it sits.
  final text = raw
      .replaceAll(RegExp(r'\[[^\]]{1,30}\]'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (text.isEmpty) return '';

  if (_isArtifact(text)) return '';

  final sentences = _splitSentences(text);
  if (sentences.length < 2) {
    // One sentence that is not an artifact: nothing to strip. Bailing out here
    // also stops the loop below from being able to empty out real speech.
    return text;
  }

  // Whisper sometimes stacks two of them ("Děkuji za pozornost. Titulky
  // vytvořil…"), so peel from the end rather than checking once.
  var end = sentences.length;
  while (end > 0 && _isArtifact(sentences[end - 1])) {
    end--;
  }

  if (end == sentences.length) return text;
  return sentences.take(end).join().trim();
}

/// True when [text] is just Whisper repeating the context it was given.
///
/// The previous chunk's tail goes up as the `prompt`, so Whisper continues a
/// sentence across the cut. Over a chunk with little speech in it, it
/// sometimes does the opposite and returns that prompt — the transcript then
/// shows a sentence twice, the second time at a moment nobody said it.
///
/// Only the *whole* output counts, and only when it is long enough to be a
/// phrase rather than a common word or two: a real "ano, souhlasím" that
/// happens to repeat something said a chunk earlier is short and survives.
bool isPromptEcho(String text, String? prompt) {
  if (prompt == null) return false;
  final t = normalizeForArtifactMatch(text);
  if (t.length < 12) return false;
  return normalizeForArtifactMatch(prompt).contains(t);
}

bool _isArtifact(String sentence) {
  final n = normalizeForArtifactMatch(sentence);
  if (n.isEmpty) return true;

  if (_kExactArtifacts.contains(n)) return true;

  for (final prefix in _kPrefixArtifacts) {
    // The bare prefix counts too: "Titulky vytvořil." with no name is just as
    // much an artifact as one with a name.
    if (n == prefix || n.startsWith('$prefix ')) return true;
  }
  return false;
}

/// Lowercase, diacritics folded, punctuation stripped, whitespace collapsed.
///
/// Exposed for the tests, which is also the only reason it is not private:
/// matching on a normalised form is the part most likely to drift.
String normalizeForArtifactMatch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final folded = _diacritics[ch] ?? ch;
    if (RegExp(r'[a-z0-9]').hasMatch(folded)) {
      buffer.write(folded);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Czech letters plus the few others Whisper can emit for Czech audio.
const Map<String, String> _diacritics = {
  'á': 'a', 'ä': 'a', 'à': 'a', 'â': 'a',
  'č': 'c', 'ć': 'c', 'ç': 'c',
  'ď': 'd',
  'é': 'e', 'ě': 'e', 'ë': 'e', 'è': 'e', 'ê': 'e',
  'í': 'i', 'ï': 'i', 'ì': 'i', 'î': 'i',
  'ň': 'n', 'ń': 'n',
  'ó': 'o', 'ö': 'o', 'ô': 'o', 'ò': 'o',
  'ř': 'r',
  'š': 's', 'ś': 's',
  'ť': 't',
  'ú': 'u', 'ů': 'u', 'ü': 'u', 'ù': 'u', 'û': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ž': 'z', 'ź': 'z', 'ż': 'z',
  'ł': 'l',
};

/// Splits on sentence terminators, keeping them attached to the sentence they
/// end, so re-joining the kept sentences reproduces the original text exactly.
List<String> _splitSentences(String text) {
  final out = <String>[];
  final buffer = StringBuffer();

  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(ch);
    if (ch == '.' || ch == '!' || ch == '?' || ch == '…') {
      out.add(buffer.toString());
      buffer.clear();
    }
  }

  final tail = buffer.toString();
  if (tail.trim().isNotEmpty) out.add(tail);
  return out;
}
