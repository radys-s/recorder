import '../stt/transcript_sanitizer.dart';

/// What a hit is, which is also how the results are grouped.
enum SearchKind { lesson, transcript, note, card, chat }

extension SearchKindLabel on SearchKind {
  String get label => switch (this) {
    SearchKind.lesson => 'Hodiny',
    SearchKind.transcript => 'Přepisy',
    SearchKind.note => 'Poznámky',
    SearchKind.card => 'Karty',
    SearchKind.chat => 'Chat v hodině',
  };
}

/// One result: what to show, and what tapping it opens.
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.excerpt,
    this.subtitle,
    this.meetingId,
    this.segmentId,
    this.noteId,
    this.cardId,
    this.at,
  });

  final SearchKind kind;

  /// The lesson, note or card the hit belongs to.
  final String title;

  /// Subject, date — whatever tells two lessons apart in a list.
  final String? subtitle;

  final SearchExcerpt excerpt;

  final int? meetingId;
  final int? segmentId;
  final int? noteId;
  final int? cardId;

  /// Sorting key across kinds: the newest lesson or note first.
  final DateTime? at;
}

/// A slice of text around a match, with the match's place in it.
class SearchExcerpt {
  const SearchExcerpt({
    required this.text,
    required this.start,
    required this.length,
  });

  const SearchExcerpt.plain(this.text) : start = 0, length = 0;

  final String text;

  /// Where the matched word sits in [text]; [length] 0 means nothing to mark.
  final int start;
  final int length;
}

/// The query as the words every result has to contain.
///
/// Folded, so „síť" finds „SIT" and the other way round — the rule the notes
/// library already searches by.
List<String> searchWords(String query) =>
    normalizeForArtifactMatch(query)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList(growable: false);

/// Whether every word of the query appears somewhere in [haystack].
bool matchesWords(String haystack, List<String> words) {
  if (words.isEmpty) return false;
  final folded = foldAligned(haystack);
  return words.every(folded.contains);
}

/// A readable slice of [source] around the first word that matched.
///
/// The window is taken on word boundaries where it can be, because a snippet
/// starting mid-word reads as a typo rather than as a quote.
SearchExcerpt excerptAround(
  String source,
  List<String> words, {
  int radius = 48,
}) {
  final flat = source.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return const SearchExcerpt.plain('');
  final folded = foldAligned(flat);

  var at = -1;
  var hitLength = 0;
  for (final word in words) {
    final found = folded.indexOf(word);
    if (found >= 0 && (at < 0 || found < at)) {
      at = found;
      hitLength = word.length;
    }
  }
  if (at < 0) {
    // Every word is in the record, just not in this field — the title matched
    // and the body is only context.
    final head = flat.length <= radius * 2
        ? flat
        : '${flat.substring(0, radius * 2).trimRight()}…';
    return SearchExcerpt.plain(head);
  }

  var start = at - radius;
  if (start <= 0) {
    start = 0;
  } else {
    final space = flat.indexOf(' ', start);
    start = space < 0 || space >= at ? start : space + 1;
  }
  var end = at + hitLength + radius;
  if (end >= flat.length) {
    end = flat.length;
  } else {
    final space = flat.lastIndexOf(' ', end);
    end = space <= at + hitLength ? end : space;
  }

  final text =
      '${start > 0 ? '…' : ''}'
      '${flat.substring(start, end)}'
      '${end < flat.length ? '…' : ''}';
  return SearchExcerpt(
    text: text,
    start: at - start + (start > 0 ? 1 : 0),
    length: hitLength,
  );
}
