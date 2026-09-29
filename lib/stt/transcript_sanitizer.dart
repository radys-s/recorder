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

/// The result of removing a likely URL hallucination from a Whisper response.
///
/// A URL is intentionally removed only when it is the entire response. A
/// teacher can genuinely say "najdete to na example.cz"; treating that as an
/// artifact would make the transcript less trustworthy than the hallucination
/// it prevents.
class TranscriptUrlFilterResult {
  const TranscriptUrlFilterResult({required this.text, this.reason});

  final String text;

  /// A privacy-safe diagnostic reason, or null when no URL was removed.
  final String? reason;

  bool get removed => reason != null;
}

/// Removes a standalone URL that is much more likely to be a Whisper artifact
/// than something said in the room.
///
/// The known Hradec Králové domain is a repeatedly observed silence
/// hallucination, so an otherwise empty response containing exactly that URL is
/// always dropped. A generic domain is only dropped with weak evidence: very
/// low transcription confidence or little voiced audio. This keeps a genuine
/// spoken address intact unless the audio itself gives us a reason to distrust
/// it.
TranscriptUrlFilterResult filterTranscriptUrlArtifact(
  String text, {
  double? confidence,
  int? voicedMs,
  int? durationMs,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return TranscriptUrlFilterResult(text: trimmed);

  final normalized = trimmed
      .toLowerCase()
      .replaceFirst(RegExp(r'''^["'“”„(\[]+'''), '')
      .replaceFirst(RegExp(r'''[.,!?;:…"'”\])]+$'''), '');
  if (_kKnownUrlArtifacts.contains(normalized)) {
    return const TranscriptUrlFilterResult(
      text: '',
      reason: 'known_url_artifact',
    );
  }

  if (!_standaloneUrl.hasMatch(normalized)) {
    return TranscriptUrlFilterResult(text: trimmed);
  }

  final lowConfidence = confidence != null && confidence < -0.9;
  final sparseVoice =
      voicedMs != null &&
      durationMs != null &&
      durationMs > 0 &&
      voicedMs * 5 < durationMs;
  if (!lowConfidence && !sparseVoice) {
    return TranscriptUrlFilterResult(text: trimmed);
  }

  return const TranscriptUrlFilterResult(
    text: '',
    reason: 'suspect_url_artifact',
  );
}

const Set<String> _kKnownUrlArtifacts = {'www.hradeckralove.org'};

/// Whole response only. It deliberately does not match a URL embedded in a
/// sentence, which is far more likely to have been said deliberately.
final RegExp _standaloneUrl = RegExp(
  r'^(?:https?://)?(?:www\.)?(?:[a-z0-9-]+\.)+[a-z]{2,24}(?:/[^\s]*)?$',
  caseSensitive: false,
);

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
  // A bracketed sound tag is never speech, wherever it sits. Parentheses are
  // only stripped for the known tags, since "(a to je důležité)" is speech.
  final text = raw
      .replaceAll(RegExp(r'\[[^\]]{1,30}\]'), ' ')
      .replaceAll(_kParenthesizedTag, ' ')
      .replaceAll(RegExp(r'[♪♫]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (text.isEmpty) return '';

  final urlFiltered = filterTranscriptUrlArtifact(text);
  if (urlFiltered.removed) return '';

  if (_isArtifact(text)) return '';

  final sentences = _splitSentences(text);
  if (sentences.length < 2) {
    // One sentence that is not an artifact: nothing to strip. Bailing out here
    // also stops the loop below from being able to empty out real speech.
    return urlFiltered.text;
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
  // Whole words only. A plain substring test called "ale to je problém" an
  // echo of "…ale to je problematické…" and threw real speech away.
  return ' ${normalizeForArtifactMatch(prompt)} '.contains(' $t ');
}

/// Trims a transcript that is implausibly long for the speech it came from.
///
/// Whisper over a chunk with a second of speech and nine of room tone can
/// return three fluent sentences; nobody said two of them. Czech speech runs
/// at ~12–15 chars/s, so the allowance here is loose on purpose — 20 chars per
/// voiced second, 10 per unvoiced second (the voiced gate under-counts a quiet
/// or distant speaker) plus a fixed 30 — and only a clear outlier is cut.
///
/// Whole sentences are removed from the end until the text fits; a first
/// sentence that alone is too long is cut at a word boundary. Null
/// [voicedMs] (rows older than the measurement) disables the check.
///
/// The check only applies when voiced time is under 10 % of the chunk. A quiet
/// or distant teacher is under-counted by the voiced gate, and a chunk with
/// real speech in a tenth of it or more is not the room-tone-plus-invention
/// case this exists for; cutting it would throw away words that were said.
String limitToSpeakingRate(
  String text, {
  required int? voicedMs,
  required int durationMs,
}) {
  if (voicedMs == null || text.isEmpty) return text;
  if (voicedMs * 10 >= durationMs) return text;
  final voicedSec = voicedMs.clamp(0, durationMs) / 1000;
  final unvoicedSec = (durationMs - voicedMs).clamp(0, durationMs) / 1000;
  final allowed = (30 + 20 * voicedSec + 10 * unvoicedSec).round();
  if (text.length <= allowed) return text;

  final sentences = _splitSentences(text);
  var kept = '';
  for (final sentence in sentences) {
    final next = kept + sentence;
    if (next.trim().length > allowed) break;
    kept = next;
  }
  if (kept.trim().isNotEmpty) return kept.trim();

  final cut = text.substring(0, allowed);
  final space = cut.lastIndexOf(' ');
  return (space > 0 ? cut.substring(0, space) : cut).trim();
}

/// Collapses a phrase Whisper got stuck repeating.
///
/// A decoding loop ("a pak jsme a pak jsme a pak jsme…") is the other shape
/// invented text takes. A run of 2–6 words repeated three or more times in a
/// row, compared on normalised words, keeps one occurrence. Two repeats are
/// left alone: "ano ano" and "velmi velmi" are real speech.
String collapseRepeats(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 6) return text;
  final keys = [for (final w in words) normalizeForArtifactMatch(w)];

  final out = <String>[];
  final outKeys = <String>[];
  var i = 0;
  var changed = false;
  while (i < words.length) {
    var skipped = false;
    // Shortest period first, so "a b a b a b a b" keeps "a b", not "a b a b".
    for (var n = 2; n <= 6; n++) {
      if (i + n * 3 > words.length) break;
      var repeats = 1;
      while (i + n * (repeats + 1) <= words.length &&
          _sameRun(keys, i, i + n * repeats, n)) {
        repeats++;
      }
      if (repeats >= 3) {
        out.addAll(words.sublist(i, i + n));
        outKeys.addAll(keys.sublist(i, i + n));
        i += n * repeats;
        skipped = true;
        changed = true;
        break;
      }
    }
    if (!skipped) {
      out.add(words[i]);
      outKeys.add(keys[i]);
      i++;
    }
  }
  return changed ? out.join(' ') : text;
}

bool _sameRun(List<String> keys, int a, int b, int n) {
  for (var k = 0; k < n; k++) {
    if (keys[a + k].isEmpty || keys[a + k] != keys[b + k]) return false;
  }
  return true;
}

/// Sound tags Whisper writes in parentheses rather than brackets.
final RegExp _kParenthesizedTag = RegExp(
  r'\(\s*(?:hudba|potlesk|smích|smich|ticho|hluk|kašel|kasel|'
  r'nesrozumitelné|nesrozumitelne|music|applause|laughter|silence|'
  r'inaudible|noise|cough)\s*\)',
  caseSensitive: false,
  unicode: true,
);

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
String normalizeForArtifactMatch(String input) =>
    foldAligned(input).trim().replaceAll(RegExp(r'\s+'), ' ');

/// The same folding, one character in one character out.
///
/// Nothing is collapsed or trimmed, so an index into the result is an index
/// into [input] — which is what lets search highlight a hit in the text the
/// user actually wrote, diacritics and punctuation included.
String foldAligned(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final folded = _diacritics[ch] ?? ch;
    // A code-unit range check rather than a RegExp per character: this runs
    // over every transcript chunk several times (detector, grounding, echo).
    final c = folded.codeUnitAt(0);
    if (folded.length == 1 &&
        ((c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39))) {
      buffer.write(folded);
    } else {
      // A rune outside the BMP is two code units in the original string, so
      // one space per code unit keeps the alignment exact.
      buffer.write(' ' * ch.length);
    }
  }
  return buffer.toString();
}

/// Czech letters plus the few others Whisper can emit for Czech audio.
const Map<String, String> _diacritics = {
  'á': 'a',
  'ä': 'a',
  'à': 'a',
  'â': 'a',
  'č': 'c',
  'ć': 'c',
  'ç': 'c',
  'ď': 'd',
  'é': 'e',
  'ě': 'e',
  'ë': 'e',
  'è': 'e',
  'ê': 'e',
  'í': 'i',
  'ï': 'i',
  'ì': 'i',
  'î': 'i',
  'ň': 'n',
  'ń': 'n',
  'ó': 'o',
  'ö': 'o',
  'ô': 'o',
  'ò': 'o',
  'ř': 'r',
  'š': 's',
  'ś': 's',
  'ť': 't',
  'ú': 'u',
  'ů': 'u',
  'ü': 'u',
  'ù': 'u',
  'û': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
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
