import '../ai/grounding.dart';
import '../data/db/tables/subject_terms_table.dart';
import 'glossary.dart';
import 'term_corrections.dart';
import 'transcript_sanitizer.dart';

/// How long the lesson lead-in in Whisper's prompt may be.
const int kLessonLeadInMaxChars = 300;

/// How many ranked terms the transcript corrector is shown.
const int kCorrectorTermCount = 40;

/// How far back "what was just said" reaches when ranking terms.
const int kListeningRecentMs = 120000;

/// A word of the subject's vocabulary as ranking needs it.
typedef VocabularyTerm = ({
  int id,
  String term,
  String? heard,
  TermSource source,
  int uses,
});

/// A card as ranking needs it.
typedef VocabularyCard = ({String title, String content, String? keywords});

/// A term chosen for this chunk, with its vocabulary row when it has one.
typedef RankedTerm = ({String term, int? id});

/// Everything the transcription needs to know about the lesson being heard.
class LessonListening {
  const LessonListening({
    this.subjectName,
    this.courseLine,
    this.topicTitle,
    this.leadIn,
    this.corrections = const [],
    this.correctionIds = const [],
    this.terms = const [],
    this.cardTitles = const [],
    this.slideTexts = const [],
    this.contextMessages = const [],
  });

  final String? subjectName;

  /// The course as „Počítačové sítě, SOŠ, obor IT, 3. ročník" — what tells the
  /// AI at which level the words are meant.
  final String? courseLine;

  /// The topic of the thematic plan this lesson is on.
  final String? topicTitle;

  /// Titles of the cards pinned for this lesson.
  final List<String> cardTitles;

  /// Text read from photos of the board and slides.
  final List<String> slideTexts;

  /// What the student typed as context.
  final List<String> contextMessages;

  /// The sentence Whisper's prompt opens with; see [lessonLeadIn].
  final String? leadIn;

  /// Misheard forms the user fixed before, applied to every new chunk.
  final List<TermCorrection> corrections;

  /// The vocabulary row of each entry in [corrections], same order.
  final List<int> correctionIds;

  /// The lesson's words, most relevant first.
  final List<RankedTerm> terms;

  bool get isEmpty => leadIn == null && corrections.isEmpty && terms.isEmpty;
}

/// Orders the words this chunk is most likely to contain.
///
/// 1. Words the student added or corrected — they are the ones that went
///    wrong before.
/// 2. The terms of the topic the lesson is on, from the thematic plan.
/// 3. Keywords, titles and names of the cards pinned for this lesson.
/// 3. The rest of the vocabulary and the other cards, by how many word stems
///    they share with what was just said, then by how often they came up.
/// 4. Names from slide photos and from what the student typed.
///
/// Duplicates are compared without case and diacritics; the first wins.
List<RankedTerm> rankLessonTerms({
  List<VocabularyTerm> terms = const [],
  List<String> topicTerms = const [],
  List<VocabularyCard> pinnedCards = const [],
  List<VocabularyCard> otherCards = const [],
  List<String> photoTexts = const [],
  List<String> contextMessages = const [],
  String recentTranscript = '',
}) {
  final out = <RankedTerm>[];
  final seen = <String>{};
  void add(String word, [int? id]) {
    final t = word.trim();
    final key = normalizeForArtifactMatch(t);
    if (key.length < 3 || t.length > 60 || !seen.add(key)) return;
    out.add((term: t, id: id));
  }

  final taught = [
    for (final t in terms)
      if (t.source == TermSource.correction || t.source == TermSource.manual) t,
  ]..sort((a, b) => b.uses.compareTo(a.uses));
  for (final t in taught) {
    add(t.term, t.id);
  }
  for (final t in topicTerms) {
    add(t);
  }

  for (final card in pinnedCards) {
    for (final k in _keywords(card)) {
      add(k);
    }
  }
  for (final card in pinnedCards) {
    add(card.title);
  }
  for (final card in pinnedCards) {
    properNouns(card.content).forEach(add);
  }

  final recent = contentStems(recentTranscript);
  int overlap(String text) =>
      recent.isEmpty ? 0 : contentStems(text).intersection(recent).length;
  final candidates = <({String term, int? id, int score, int uses})>[
    for (final t in terms)
      if (t.source != TermSource.correction && t.source != TermSource.manual)
        (term: t.term, id: t.id, score: overlap(t.term), uses: t.uses),
    for (final card in otherCards) ...[
      for (final k in _keywords(card))
        (term: k, id: null, score: overlap('$k ${card.title}'), uses: 0),
      (term: card.title, id: null, score: overlap(card.title), uses: 0),
    ],
  ];
  final order = [for (var i = 0; i < candidates.length; i++) i]
    ..sort((a, b) {
      final x = candidates[a], y = candidates[b];
      if (x.score != y.score) return y.score.compareTo(x.score);
      if (x.uses != y.uses) return y.uses.compareTo(x.uses);
      return a.compareTo(b);
    });
  for (final i in order) {
    add(candidates[i].term, candidates[i].id);
  }

  for (final text in [...photoTexts, ...contextMessages]) {
    properNouns(text).forEach(add);
  }
  return out;
}

Iterable<String> _keywords(VocabularyCard card) =>
    (card.keywords ?? '').split(',').where((k) => k.trim().isNotEmpty);

/// The opening of Whisper's prompt: „Hodina: Počítačové sítě, 3. ročník —
/// téma: Směrování, Babička. Pojmy: OSPF, RIP."
///
/// Whisper copies spelling and style from a prompt that reads like the
/// transcript before it, so a sentence works better than a bare list of words.
/// Terms that do not fit are left out whole, never cut.
String? lessonLeadIn({
  String? subjectName,
  String? courseLine,
  String? topicTitle,
  List<String> cardTitles = const [],
  List<RankedTerm> terms = const [],
  int maxChars = kLessonLeadInMaxChars,
}) {
  final course = courseLine?.trim() ?? '';
  final name = course.isNotEmpty ? course : (subjectName?.trim() ?? '');
  final topic = topicTitle?.trim() ?? '';
  // The topic leads the list of what the lesson is about; the pinned cards
  // follow it, joined the same way.
  final subjects = <String>[
    if (topic.isNotEmpty) topic,
    for (final t in cardTitles)
      if (t.trim().isNotEmpty) t.trim(),
  ];
  final titles = <String>[];
  var head = name.isEmpty ? '' : 'Hodina: $name';
  for (final t in subjects) {
    final label = titles.isEmpty && topic.isNotEmpty ? 'téma: $t' : t;
    final next = titles.isEmpty
        ? (head.isEmpty ? label : '$head — $label')
        : '$head, $label';
    if (next.length + 1 > maxChars) break;
    titles.add(t);
    head = next;
  }

  final shown = {for (final t in titles) normalizeForArtifactMatch(t)};
  var body = '';
  for (final term in terms) {
    if (shown.contains(normalizeForArtifactMatch(term.term))) continue;
    final next = body.isEmpty ? 'Pojmy: ${term.term}' : '$body, ${term.term}';
    final total = head.isEmpty
        ? next.length + 1
        : head.length + next.length + 3;
    if (total > maxChars) break;
    body = next;
  }

  final parts = [if (head.isNotEmpty) '$head.', if (body.isNotEmpty) '$body.'];
  return parts.isEmpty ? null : parts.join(' ');
}

/// The terms listed under „Klíčové pojmy" in výpisky: the part of each
/// `- pojem – definice` line before the dash.
///
/// Anything that does not look like a term — a whole sentence, a line with no
/// definition — is left out; the vocabulary is better short than noisy.
List<String> keyTermsFromNotes(String notes) {
  final out = <String>[];
  var inSection = false;
  for (final raw in notes.split('\n')) {
    final line = raw.trim().replaceAll('*', '').replaceAll('#', '').trim();
    if (line.isEmpty) continue;
    final bullet = RegExp(r'^[-•–]\s+').firstMatch(line);
    if (bullet == null) {
      inSection = normalizeForArtifactMatch(line).startsWith('klicove pojmy');
      continue;
    }
    if (!inSection) continue;
    final item = line.substring(bullet.end);
    final split = RegExp(r'\s[–—-]\s|:\s').firstMatch(item);
    if (split == null) continue;
    final term = item.substring(0, split.start).trim();
    final words = term.split(RegExp(r'\s+')).length;
    if (term.length < 3 || term.length > 60 || words > 5) continue;
    out.add(term);
  }
  return out;
}

/// Vocabulary rows whose word appears in [text] as whole words.
Set<int> termsMentioned(String text, Iterable<RankedTerm> terms) {
  final words = ' ${_folded(text)} ';
  return {
    for (final t in terms)
      if (t.id != null &&
          _folded(t.term).isNotEmpty &&
          words.contains(' ${_folded(t.term)} '))
        t.id!,
  };
}

final _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

String _folded(String text) => [
  for (final m in _wordPattern.allMatches(text))
    normalizeForArtifactMatch(m[0]!),
].where((w) => w.isNotEmpty).join(' ');
