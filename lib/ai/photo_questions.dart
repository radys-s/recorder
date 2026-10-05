import 'question_detector.dart';

/// Most questions one photo is answered for. A worksheet can hold dozens; the
/// answer has to stay a reply, not a chapter.
const int kMaxPhotoQuestions = 8;

final _numbered = RegExp(
  r'^\s*(?:\(?\d{1,2}[.)]|\(?[a-zA-Z][.)])\s+(.*\S)\s*$',
);
final _bullet = RegExp(r'^\s*(?:[-–•*]\s+)(.*\S)\s*$');

/// Task verbs a teacher puts on a worksheet; an imperative is a question to
/// the student even with no question mark ("Vysvětli pojem realismus.").
final _taskOpener = RegExp(
  r'^(vysvětli|vysvetli|popiš|popis|uveď|uved|vyjmenuj|definuj|porovnej|'
  r'shrň|shrn|charakterizuj|zdůvodni|zduvodni|napiš|napis|určete|urcete|urči|'
  r'urci|vypočítej|vypocitej|spočítej|spocitej|najdi|doplň|odpověz|'
  r'odpovez|řekni|rekni|explain|describe|define|compare|list|solve|find|'
  r'calculate)(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// The questions and tasks a student is expected to answer in [text] (the
/// text read off a photo), in order, without list markers. Empty when none.
///
/// A local fallback for when the model returns no `questions` of its own; a
/// line counts when it ends in `?`, opens with a task verb, is a numbered or
/// lettered item that reads like a question, or passes [looksLikeQuestion].
List<String> extractQuestions(String text) {
  final found = <String>[];
  final seen = <String>{};
  for (final raw in text.split('\n')) {
    var line = raw.trim();
    if (line.length < 6) continue;
    var listed = false;
    final num = _numbered.firstMatch(line);
    if (num != null) {
      line = num.group(1)!.trim();
      listed = true;
    } else {
      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        line = bullet.group(1)!.trim();
        listed = true;
      }
    }
    if (line.length < 6) continue;
    final isQuestion =
        line.endsWith('?') ||
        _taskOpener.hasMatch(line) ||
        looksLikeQuestion(line);
    // An unmarked list item is a fact more often than a question; a numbered
    // one is only kept when it reads like one, which `isQuestion` decides.
    if (!isQuestion) continue;
    if (!listed && !line.endsWith('?') && !_taskOpener.hasMatch(line)) {
      // A plain line that only matched the loose detector must also be a
      // whole sentence, so a slide title with "co" in it does not count.
      if (line.split(RegExp(r'\s+')).length < 4) continue;
    }
    if (seen.add(line.toLowerCase())) found.add(line);
    if (found.length >= kMaxPhotoQuestions) break;
  }
  return found;
}
