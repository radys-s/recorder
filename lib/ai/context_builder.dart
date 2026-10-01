import 'grounding.dart';

/// A rough token count. Czech tokenises worse than English — about three
/// characters a token — and overestimating is the safe direction under a
/// per-minute cap that a single request is also measured against.
int estimateTokens(String text) => (text.length / 3).ceil();

/// One context card as the builder sees it.
class LessonCard {
  const LessonCard({
    required this.id,
    required this.title,
    required this.content,
    this.summary,
    this.pinned = false,
  });

  final int id;
  final String title;
  final String content;
  final String? summary;

  /// Pinned for this lesson: always contributes, not only when talked about.
  final bool pinned;
}

/// Everything the student gave the AI for one lesson.
class LessonMaterial {
  const LessonMaterial({
    this.subjectName,
    this.courseLine,
    this.topicTitle,
    this.globalRules,
    this.subjectRules,
    this.lessonRules,
    this.chatRules = const [],
    this.chatContext = const [],
    this.cards = const [],
  });

  final String? subjectName;

  /// The course as „Počítačové sítě, SOŠ, obor IT, 3. ročník": at which level
  /// the answer has to be pitched.
  final String? courseLine;

  /// The topic of the thematic plan this lesson is on.
  final String? topicTitle;
  final String? globalRules;
  final String? subjectRules;
  final String? lessonRules;

  /// Rule messages typed in the chat, oldest first.
  final List<String> chatRules;

  /// Context messages typed in the chat, oldest first.
  final List<String> chatContext;

  /// Pinned cards first, then the rest of the subject's cards.
  final List<LessonCard> cards;

  /// A lesson with a subject is answered in class mode.
  bool get isLesson => subjectName != null;

  bool get isEmpty =>
      subjectName == null &&
      _blank(globalRules) &&
      _blank(subjectRules) &&
      _blank(lessonRules) &&
      chatRules.isEmpty &&
      chatContext.isEmpty &&
      cards.isEmpty;

  static bool _blank(String? s) => s == null || s.trim().isEmpty;
}

/// How many tokens each part of the context may take.
///
/// Unused shares roll over to the transcript tail, so a lesson with no cards
/// sees more of what was said rather than a shorter request.
class ContextBudget {
  const ContextBudget({
    required this.rules,
    required this.cards,
    required this.chat,
    required this.tail,
  });

  /// The automatic answer call. Groq's 8 000 TPM cap is shared with the web
  /// hop and with the next segment's call, so this stays near 3 000.
  static const automatic =
      ContextBudget(rules: 300, cards: 1200, chat: 400, tail: 700);

  /// A question typed by the student: rarer, and worth a bigger look.
  static const direct =
      ContextBudget(rules: 400, cards: 2600, chat: 800, tail: 1200);

  /// A typed question answered by Gemini, whose context window and free tier
  /// are not measured against Groq's 8 000 tokens a minute: whole pinned cards
  /// instead of their best chunks, and most of the lesson.
  static const gemini =
      ContextBudget(rules: 1000, cards: 20000, chat: 3000, tail: 8000);

  /// The automatic answer call in a lesson, on Gemini: whole pinned cards,
  /// every photo the student took, and about the last five minutes. Smaller
  /// than [gemini] because it runs for every candidate question and has to
  /// come back while the room is still on it.
  static const geminiLive =
      ContextBudget(rules: 800, cards: 10000, chat: 4000, tail: 2500);

  /// A request that goes to a roomier service than Groq's free tier (Mistral,
  /// Cerebras, a school model): well above [automatic], still far below
  /// Gemini's whole-card budget because those services are slower to answer.
  static const routed =
      ContextBudget(rules: 600, cards: 5000, chat: 1500, tail: 2500);

  final int rules;
  final int cards;
  final int chat;
  final int tail;

  int get total => rules + cards + chat + tail;
}

/// What goes into the request.
class LessonContext {
  const LessonContext({
    required this.material,
    required this.tail,
    required this.cardIds,
  });

  /// The labelled block of subject, rules, student context and cards; empty
  /// when there is none.
  final String material;

  /// The end of the transcript, cut on a word boundary.
  final String tail;

  /// Titles of the cards actually included, to their ids. Only a card the
  /// model was shown can be named as a basis.
  final Map<String, int> cardIds;

  int get tokens => estimateTokens(material) + estimateTokens(tail);

  /// The id of the card the model named, tolerating case and quotes.
  int? cardIdFor(String title) {
    final wanted = _key(title);
    if (wanted.isEmpty) return null;
    for (final entry in cardIds.entries) {
      if (_key(entry.key) == wanted) return entry.value;
    }
    return null;
  }

  static String _key(String s) => s
      .trim()
      .replaceAll(RegExp('^["\'„“\\[]+|["\'“”\\]]+\$'), '')
      .trim()
      .toLowerCase();
}

/// Cards are cut into pieces of about this many characters.
const int kCardChunkChars = 600;

/// An unpinned card joins only when a chunk shares this many word stems with
/// what was just said — one shared word is coincidence.
const int kUnpinnedMinScore = 2;

/// Assembles the context for one answer call under [budget].
///
/// [transcript] is the lesson before the newest passage; [focus] is the newest
/// passage plus the segment before it, which is what card chunks are scored
/// against.
LessonContext buildLessonContext({
  required LessonMaterial material,
  required String transcript,
  required String focus,
  ContextBudget budget = ContextBudget.automatic,
}) {
  // Counted in characters, three to a token, so the sum of the parts can never
  // round up past the budget.
  final lines = <String>[];
  var used = 0;

  final rules = _section(
    heading: 'Rules the student set (later ones override earlier ones):',
    entries: [
      ?_line('Everywhere', material.globalRules),
      ?_line('This subject', material.subjectRules),
      ?_line('This lesson', material.lessonRules),
      for (final r in material.chatRules) ?_line('Said in class', r),
    ],
    lead: [
      if (material.courseLine?.trim().isNotEmpty ?? false)
        'Course: ${material.courseLine!.trim()}'
      else if (material.subjectName case final name?)
        'Subject: $name',
      if (material.topicTitle?.trim().isNotEmpty ?? false)
        'Topic of this lesson: ${material.topicTitle!.trim()}',
    ],
    budgetChars: budget.rules * 3,
    separated: false,
  );
  lines.addAll(rules.lines);
  used += rules.chars;

  final chat = _section(
    heading: 'What the student says the lesson is about:',
    entries: [for (final c in material.chatContext) ?_line(null, c)],
    budgetChars: budget.chat * 3,
    separated: lines.isNotEmpty,
  );
  lines.addAll(chat.lines);
  used += chat.chars;

  final cards = _cards(
    material.cards,
    focus,
    budget.cards * 3,
    separated: lines.isNotEmpty,
  );
  lines.addAll(cards.lines);
  used += cards.chars;

  final spare = (budget.rules + budget.chat + budget.cards) * 3 - used;
  final tailChars = budget.tail * 3 + (spare > 0 ? spare : 0);

  return LessonContext(
    material: lines.join('\n'),
    tail: tailOf(transcript.trim(), tailChars),
    cardIds: cards.ids,
  );
}

/// The last [maxChars] of [text], starting on a whole word.
String tailOf(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  final cut = text.substring(text.length - maxChars);
  final space = cut.indexOf(' ');
  return space < 0 ? cut : cut.substring(space + 1);
}

/// Splits card content into pieces of at most [maxChars], on paragraphs, then
/// sentences, then words.
List<String> chunkCardContent(String content, {int maxChars = kCardChunkChars}) {
  final pieces = <String>[];
  for (final paragraph in content.split(RegExp(r'\n\s*\n'))) {
    final p = paragraph.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (p.isEmpty) continue;
    if (p.length <= maxChars) {
      pieces.add(p);
      continue;
    }
    for (final sentence in p.split(RegExp(r'(?<=[.!?…])\s+'))) {
      if (sentence.length <= maxChars) {
        pieces.add(sentence);
      } else {
        pieces.addAll(_splitWords(sentence, maxChars));
      }
    }
  }

  // Small neighbours are merged back, so a card of short lines is not scored
  // one line at a time.
  final merged = <String>[];
  for (final piece in pieces) {
    if (merged.isNotEmpty && merged.last.length + 1 + piece.length <= maxChars) {
      merged[merged.length - 1] = '${merged.last}\n$piece';
    } else {
      merged.add(piece);
    }
  }
  return merged;
}

List<String> _splitWords(String text, int maxChars) {
  final out = <String>[];
  var current = StringBuffer();
  for (final word in text.split(' ')) {
    final w = word.length > maxChars ? word.substring(0, maxChars) : word;
    if (current.isNotEmpty && current.length + 1 + w.length > maxChars) {
      out.add(current.toString());
      current = StringBuffer();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(w);
  }
  if (current.isNotEmpty) out.add(current.toString());
  return out;
}

String? _line(String? label, String? text) {
  final flat = text?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (flat.isEmpty) return null;
  return label == null ? '- $flat' : '- $label: $flat';
}

typedef _Built = ({List<String> lines, int chars});

/// A heading and as many entries as fit, the newest kept first — later
/// entries are the ones that override — but printed oldest first.
_Built _section({
  required String heading,
  required List<String> entries,
  required int budgetChars,
  required bool separated,
  List<String> lead = const [],
}) {
  if (entries.isEmpty && lead.isEmpty) return (lines: const [], chars: 0);

  var chars = separated ? 1 : 0;
  final out = <String>[];
  for (final l in lead) {
    if (chars + l.length + 1 > budgetChars) break;
    out.add(l);
    chars += l.length + 1;
  }
  if (entries.isEmpty) return (lines: out, chars: out.isEmpty ? 0 : chars);

  final headingCost = heading.length + 1;
  if (chars + headingCost >= budgetChars) {
    return (lines: [if (separated && out.isNotEmpty) '', ...out],
        chars: out.isEmpty ? 0 : chars);
  }
  chars += headingCost;

  final kept = <String>[];
  for (final entry in entries.reversed) {
    final room = budgetChars - chars;
    if (entry.length + 1 <= room) {
      kept.add(entry);
      chars += entry.length + 1;
    } else if (kept.isEmpty && room > 40) {
      // The newest entry is the one that matters most; better cut than gone.
      final cut = '${entry.substring(0, room - 2)}…';
      kept.add(cut);
      chars += cut.length + 1;
      break;
    } else {
      break;
    }
  }
  if (kept.isEmpty && out.isEmpty) return (lines: const [], chars: 0);

  return (
    lines: [
      if (separated) '',
      ...out,
      if (kept.isNotEmpty) heading,
      ...kept.reversed,
    ],
    chars: kept.isEmpty ? chars - headingCost : chars,
  );
}

class _Piece {
  _Piece(this.card, this.cardOrder, this.index, this.text, this.score);
  final LessonCard card;
  final int cardOrder;

  /// -1 for the summary, which prints before any chunk.
  final int index;
  final String text;
  final int score;
}

({List<String> lines, int chars, Map<String, int> ids}) _cards(
  List<LessonCard> cards,
  String focus,
  int budgetChars, {
  required bool separated,
}) {
  if (cards.isEmpty || budgetChars <= 0) {
    return (lines: const [], chars: 0, ids: const {});
  }
  const heading = "Cards (the student's saved material):";
  var chars = heading.length + 1 + (separated ? 1 : 0);
  if (chars >= budgetChars) return (lines: const [], chars: 0, ids: const {});

  final focusStems = contentStems(focus);
  final mustHave = <_Piece>[];
  final scored = <_Piece>[];

  for (var c = 0; c < cards.length; c++) {
    final card = cards[c];
    final titleHit =
        contentStems(card.title).intersection(focusStems).isNotEmpty ? 2 : 0;
    final chunks = chunkCardContent(card.content);
    final summary = card.summary?.trim() ?? '';

    var firstChunk = 0;
    if (card.pinned) {
      if (summary.isNotEmpty) {
        mustHave.add(_Piece(card, c, -1, summary, 0));
      } else if (chunks.isNotEmpty) {
        mustHave.add(_Piece(card, c, 0, chunks.first, 0));
        firstChunk = 1;
      } else {
        mustHave.add(_Piece(card, c, -1, card.title, 0));
      }
    }
    for (var i = firstChunk; i < chunks.length; i++) {
      final score =
          contentStems(chunks[i]).intersection(focusStems).length + titleHit;
      final minimum = card.pinned ? 1 : kUnpinnedMinScore;
      if (score >= minimum) scored.add(_Piece(card, c, i, chunks[i], score));
    }
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    if (a.card.pinned != b.card.pinned) return a.card.pinned ? -1 : 1;
    final byCard = a.cardOrder.compareTo(b.cardOrder);
    return byCard != 0 ? byCard : a.index.compareTo(b.index);
  });

  final included = <int, List<_Piece>>{};
  final order = <int>[];

  bool add(_Piece piece, {required bool mayCut}) {
    final isNewCard = !included.containsKey(piece.cardOrder);
    final header = '[${piece.card.title}]';
    final headerCost = isNewCard ? header.length + 1 : 0;
    var text = piece.text;
    var cost = headerCost + text.length + 1;
    if (chars + cost > budgetChars) {
      final room = budgetChars - chars - headerCost - 2;
      if (!mayCut || room < 120) return false;
      text = '${text.substring(0, room)}…';
      cost = headerCost + text.length + 1;
    }
    chars += cost;
    if (isNewCard) order.add(piece.cardOrder);
    (included[piece.cardOrder] ??= []).add(_Piece(
      piece.card,
      piece.cardOrder,
      piece.index,
      text,
      piece.score,
    ));
    return true;
  }

  for (final piece in mustHave) {
    add(piece, mayCut: true);
  }
  for (final piece in scored) {
    add(piece, mayCut: false);
  }
  if (included.isEmpty) return (lines: const [], chars: 0, ids: const {});

  // Pinned cards first, in their own order; then the rest as they earned it.
  order.sort((a, b) {
    final pa = cards[a].pinned, pb = cards[b].pinned;
    if (pa != pb) return pa ? -1 : 1;
    return pa ? a.compareTo(b) : 0;
  });

  final lines = <String>[if (separated) '', heading];
  final ids = <String, int>{};
  for (final c in order) {
    final pieces = included[c]!..sort((a, b) => a.index.compareTo(b.index));
    lines.add('[${cards[c].title}]');
    ids[cards[c].title] = cards[c].id;
    for (final piece in pieces) {
      lines.add(piece.text);
    }
  }
  return (lines: lines, chars: chars, ids: ids);
}
