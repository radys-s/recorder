import '../data/db/app_database.dart' show SyllabusTopic;
import '../stt/transcript_sanitizer.dart' show normalizeForArtifactMatch;
import 'grounding.dart';
import 'json_extract.dart';

/// Longest topic title kept; matches the column.
const int kSyllabusTitleMaxChars = 160;
const int kSyllabusDescriptionMaxChars = 600;
const int kSyllabusTermsPerTopic = 15;
const int kSyllabusMaxTopics = 80;

/// A topic read from a plan, before it is saved.
class SyllabusTopicDraft {
  const SyllabusTopicDraft({
    required this.title,
    this.description,
    this.terms = const [],
    this.monthFrom,
    this.monthTo,
  });

  final String title;
  final String? description;
  final List<String> terms;

  /// 1–12, or null when the plan gives no time.
  final int? monthFrom;
  final int? monthTo;

  SyllabusTopicDraft copyWith({
    String? title,
    String? description,
    List<String>? terms,
  }) => SyllabusTopicDraft(
    title: title ?? this.title,
    description: description ?? this.description,
    terms: terms ?? this.terms,
    monthFrom: monthFrom,
    monthTo: monthTo,
  );

  @override
  String toString() => 'SyllabusTopicDraft($title, $monthFrom-$monthTo)';
}

/// The topics in a model reply, in the order given. A topic without a title is
/// left out; terms may come as a list or a comma string, months as numbers or
/// Czech month names.
List<SyllabusTopicDraft> parseSyllabus(String raw) {
  final decoded = extractJsonObject(raw);
  final list = decoded?['topics'];
  if (list is! List) return const [];
  final out = <SyllabusTopicDraft>[];
  final seen = <String>{};
  for (final item in list) {
    if (out.length >= kSyllabusMaxTopics) break;
    if (item is! Map) continue;
    final title = _clip(_string(item['title']), kSyllabusTitleMaxChars);
    if (title == null || !seen.add(normalizeForArtifactMatch(title))) continue;
    var from = parseMonth(item['month_from']);
    var to = parseMonth(item['month_to']);
    from ??= to;
    to ??= from;
    out.add(
      SyllabusTopicDraft(
        title: title,
        description: _clip(
          _string(item['description']),
          kSyllabusDescriptionMaxChars,
        ),
        terms: parseTerms(item['terms']),
        monthFrom: from,
        monthTo: to,
      ),
    );
  }
  return out;
}

/// Terms from a list or a comma/semicolon string, trimmed, de-duplicated
/// without regard to case or diacritics, capped.
List<String> parseTerms(Object? value) {
  final parts = switch (value) {
    final List<Object?> list => [
      for (final v in list)
        if (v is String) v,
    ],
    final String s => s.split(RegExp('[,;\n]')),
    _ => const <String>[],
  };
  final out = <String>[];
  final seen = <String>{};
  for (final part in parts) {
    final term = part.trim();
    if (term.isEmpty || term.length > 80) continue;
    if (!seen.add(normalizeForArtifactMatch(term))) continue;
    out.add(term);
    if (out.length >= kSyllabusTermsPerTopic) break;
  }
  return out;
}

/// 1–12 from a number, a numeric string („9", „9.") or a Czech month name in
/// any case or form („září", „v listopadu", „cervenec"). Null otherwise.
int? parseMonth(Object? value) {
  if (value is int) return value >= 1 && value <= 12 ? value : null;
  if (value is double) return parseMonth(value.round());
  if (value is! String) return null;
  final folded = normalizeForArtifactMatch(value);
  if (folded.isEmpty) return null;
  final digits = RegExp(r'^\d{1,2}$').firstMatch(folded.split(' ').first);
  if (digits != null) return parseMonth(int.parse(digits.group(0)!));
  for (final word in folded.split(' ')) {
    for (final (prefix, month) in _monthPrefixes) {
      if (word.startsWith(prefix)) return month;
    }
  }
  return null;
}

/// Folded prefixes; the July forms („cervenec", „cervence", „cervenci") are
/// checked before „cerven", which they all start with.
const _monthPrefixes = [
  ('led', 1),
  ('unor', 2),
  ('brez', 3),
  ('dub', 4),
  ('kvet', 5),
  ('cervenec', 7),
  ('cervenc', 7),
  ('cerven', 6),
  ('cervn', 6),
  ('srp', 8),
  ('zar', 9),
  ('rij', 10),
  ('listop', 11),
  ('prosin', 12),
  ('january', 1),
  ('february', 2),
  ('march', 3),
  ('april', 4),
  ('may', 5),
  ('june', 6),
  ('july', 7),
  ('august', 8),
  ('september', 9),
  ('october', 10),
  ('november', 11),
  ('december', 12),
];

/// Position of a month in the Czech school year: September 0 … June 9. The
/// summer counts as its nearer end — July as June, August as September.
int schoolMonthIndex(int month) => switch (month) {
  7 => 9,
  8 => 0,
  _ => (month + 3) % 12,
};

/// The topics a plan puts at [date], in plan order.
///
/// Topics whose month range covers the date win. Without months anywhere the
/// plan is spread evenly over September–June and the topic at that point is
/// taken. With months that miss the date (a holiday, a gap in the plan) the
/// nearest range is.
List<SyllabusTopic> currentTopics(List<SyllabusTopic> topics, DateTime date) {
  if (topics.isEmpty) return const [];
  final sorted = [...topics]..sort((a, b) => a.ord.compareTo(b.ord));
  final now = schoolMonthIndex(date.month);
  final timed = [
    for (final t in sorted)
      if (t.monthFrom != null) t,
  ];

  if (timed.isEmpty) {
    final days = DateTime(date.year, date.month + 1, 0).day;
    final summer = date.month == 7 || date.month == 8;
    final within = summer
        ? (date.month == 7 ? 0.999 : 0.0)
        : (date.day - 1) / days;
    final position = (now + within) / 10;
    final index = (position * sorted.length).floor().clamp(
      0,
      sorted.length - 1,
    );
    return [sorted[index]];
  }

  int distance(SyllabusTopic t) {
    final from = schoolMonthIndex(t.monthFrom!);
    final to = schoolMonthIndex(t.monthTo ?? t.monthFrom!);
    final lo = from <= to ? from : to;
    final hi = from <= to ? to : from;
    if (now < lo) return lo - now;
    if (now > hi) return now - hi;
    return 0;
  }

  final best = timed.map(distance).reduce((a, b) => a < b ? a : b);
  return [
    for (final t in timed)
      if (distance(t) == best) t,
  ];
}

/// The topic a lesson is about, judged from what is being said.
///
/// Each topic scores the distinct keys of its title and terms (see
/// [topicKeys]) that occur in [recentTranscript]. The best topic is returned
/// only on a clear lead: at least [minHits] keys and [margin] more than the
/// runner-up. Anything less keeps [current], so the chip does not flicker
/// between two neighbouring topics.
SyllabusTopic? detectTopic(
  List<SyllabusTopic> topics,
  String recentTranscript, {
  SyllabusTopic? current,
  int minHits = 2,
  int margin = 2,
}) {
  if (topics.isEmpty) return current;
  final heard = _keys(recentTranscript, abbreviationsOnly: false);
  if (heard.isEmpty) return current;

  final scored = <(SyllabusTopic, int)>[
    for (final t in topics) (t, topicKeys(t).where(heard.contains).length),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final (best, bestHits) = scored.first;
  final runnerUp = scored.length > 1 ? scored[1].$2 : 0;
  if (bestHits >= minHits && bestHits - runnerUp >= margin) return best;
  return current;
}

/// What a topic is recognised by: the four-letter stems of its title and
/// terms, plus its short abbreviations („IP", „DNS", „RIP"), which are too
/// short to be stems but are exactly what a lesson in such a subject says.
Set<String> topicKeys(SyllabusTopic topic) => _keys(
  '${topic.title} ${(topic.terms ?? '').replaceAll(',', ' ')}',
  abbreviationsOnly: true,
);

final _shortWord = RegExp(r'[\p{L}\p{N}]{2,3}', unicode: true);

/// Stems plus two- or three-letter words, folded. From a topic only the
/// upper-case short words count ([abbreviationsOnly]) — „a", „v", „na" are not
/// what a topic is about; a transcript contributes every short word, since
/// Whisper may write an abbreviation in lower case.
Set<String> _keys(String text, {required bool abbreviationsOnly}) => {
  ...contentStems(text),
  for (final m in _shortWord.allMatches(text))
    if (!abbreviationsOnly || m.group(0) == m.group(0)!.toUpperCase())
      if (_isWhole(text, m)) normalizeForArtifactMatch(m.group(0)!),
};

bool _isWhole(String text, RegExpMatch m) {
  bool letter(int i) =>
      i >= 0 &&
      i < text.length &&
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text[i]);
  return !letter(m.start - 1) && !letter(m.end);
}

String? _string(Object? value) => value is String ? value : null;

String? _clip(String? value, int max) {
  final trimmed = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.length <= max ? trimmed : trimmed.substring(0, max).trim();
}
