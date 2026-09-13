import '../stt/transcript_sanitizer.dart';

/// Whether [claim] is made of words that actually occur in [source].
///
/// The answer model is asked to quote the words the question was asked in,
/// and it mostly does — but "mostly" is how a card ends up headed by a
/// question nobody in the room asked. The prompt is the request; this is the
/// check that holds it to it, the same split as `stripTrailingLinks`.
///
/// Words are compared on a folded four-letter prefix, because Czech inflects:
/// "rozpočet" and "rozpočtu" must count as the same word, and a transcript
/// that lost its diacritics must still match. Words shorter than four letters
/// are ignored — they are the prepositions and particles every sentence
/// shares, and counting them would let anything through.
///
/// A claim with fewer than two such words is too short to judge and passes.
bool isGroundedIn(String claim, String source, {double minShare = 2 / 3}) {
  final words = _contentWords(claim);
  if (words.length < 2) return true;

  final available = {for (final w in _contentWords(source)) w.substring(0, 4)};
  final hits = words.where((w) => available.contains(w.substring(0, 4))).length;
  return hits >= words.length * minShare;
}

List<String> _contentWords(String text) => [
      for (final w in normalizeForArtifactMatch(text).split(' '))
        if (w.length >= 4) w,
    ];
