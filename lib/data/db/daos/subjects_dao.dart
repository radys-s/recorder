import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/chat_messages_table.dart';
import '../tables/context_cards_table.dart';
import '../tables/meetings_table.dart';
import '../tables/saved_notes_table.dart';
import '../tables/subjects_table.dart';

part 'subjects_dao.g.dart';

/// A subject with what hangs off it, for the subjects list.
class SubjectSummary {
  const SubjectSummary({
    required this.subject,
    required this.cardCount,
    required this.noteCount,
    required this.lessonCount,
  });

  final Subject subject;
  final int cardCount;
  final int noteCount;
  final int lessonCount;
}

/// Subjects, their context cards, and which cards a lesson has pinned.
///
/// Creating and renaming a subject stays in `SavedNotesDao` (`createFolder`,
/// `renameFolder`), because the library was there first and both screens have
/// to agree on the same dedupe rule.
@DriftAccessor(
  tables: [
    Subjects,
    ContextCards,
    CardImages,
    MeetingCards,
    TimetableSlots,
    Meetings,
    SavedNotes,
    ChatMessages,
  ],
)
class SubjectsDao extends DatabaseAccessor<AppDatabase>
    with _$SubjectsDaoMixin {
  SubjectsDao(super.db);

  static const maxCardTitleLength = 120;
  static const paletteSize = 8;

  Stream<List<SubjectSummary>> watchSubjects() => _subjectsQuery().watch();

  /// The same list once, for a decision made at a single moment (the start
  /// sheet) rather than a screen that follows changes.
  Future<List<SubjectSummary>> allSubjects() => _subjectsQuery().get();

  Selectable<SubjectSummary> _subjectsQuery() {
    Expression<int> countOf(
      TableInfo table,
      GeneratedColumn<int> idColumn,
      GeneratedColumn<int> subjectColumn,
    ) =>
        subqueryExpression<int>(
          selectOnly(table)
            ..addColumns([idColumn.count()])
            ..where(subjectColumn.equalsExp(subjects.id)),
        );

    final cards = countOf(contextCards, contextCards.id, contextCards.subjectId);
    final notes = countOf(savedNotes, savedNotes.id, savedNotes.folderId);
    final lessons = countOf(meetings, meetings.id, meetings.subjectId);

    final query = select(subjects).join(const [])
      ..addColumns([cards, notes, lessons])
      ..orderBy([
        OrderingTerm.asc(subjects.sortOrder),
        OrderingTerm.asc(subjects.createdAt),
        OrderingTerm.asc(subjects.id),
      ]);

    return query.map((row) => SubjectSummary(
          subject: row.readTable(subjects),
          cardCount: row.read(cards) ?? 0,
          noteCount: row.read(notes) ?? 0,
          lessonCount: row.read(lessons) ?? 0,
        ));
  }

  Stream<Subject?> watchSubject(int id) =>
      (select(subjects)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<Subject?> subject(int id) =>
      (select(subjects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> setSubjectRules(int id, String? rules) =>
      (update(subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(rules: Value(_optional(rules))),
      );

  Future<void> setSubjectColor(int id, int colorIndex) =>
      (update(subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(colorIndex: Value(colorIndex % paletteSize)),
      );

  /// Deletes a subject with its cards and timetable. Saved notes stay, unfiled,
  /// and recorded lessons stay, without a subject: both are the user's record
  /// and outlive the label on them.
  Future<void> deleteSubject(int id) => transaction(() async {
        final cardIds = selectOnly(contextCards)
          ..addColumns([contextCards.id])
          ..where(contextCards.subjectId.equals(id));
        await (delete(meetingCards)..where((t) => t.cardId.isInQuery(cardIds)))
            .go();
        await (delete(cardImages)..where((t) => t.cardId.isInQuery(cardIds)))
            .go();
        await (delete(contextCards)..where((t) => t.subjectId.equals(id))).go();
        await (delete(timetableSlots)..where((t) => t.subjectId.equals(id)))
            .go();
        await (update(savedNotes)..where((t) => t.folderId.equals(id)))
            .write(const SavedNotesCompanion(folderId: Value(null)));
        await (update(meetings)..where((t) => t.subjectId.equals(id)))
            .write(const MeetingsCompanion(subjectId: Value(null)));
        await (delete(subjects)..where((t) => t.id.equals(id))).go();
      });

  // ---------------------------------------------------------------- cards

  /// Most recently edited first.
  Stream<List<ContextCard>> watchCards(int subjectId) => (select(contextCards)
        ..where((t) => t.subjectId.equals(subjectId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.updatedAt),
          (t) => OrderingTerm.desc(t.id),
        ]))
      .watch();

  Future<List<ContextCard>> cards(int subjectId) => (select(contextCards)
        ..where((t) => t.subjectId.equals(subjectId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.updatedAt),
          (t) => OrderingTerm.desc(t.id),
        ]))
      .get();

  Stream<ContextCard?> watchCard(int id) =>
      (select(contextCards)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<ContextCard?> card(int id) =>
      (select(contextCards)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Stores a digest, but only while the card still holds [content] — the one
  /// it was made from. An edit that lands while the call is out wins, and its
  /// own save triggers a fresh digest. Does not touch `updatedAt`: nothing the
  /// user wrote changed. True when written.
  Future<bool> setCardDigest(
    int id, {
    required String content,
    required String summary,
    required String keywords,
  }) async {
    final written = await (update(contextCards)
          ..where((t) => t.id.equals(id) & t.content.equals(content)))
        .write(ContextCardsCompanion(
      summary: Value(summary),
      keywords: Value(keywords.isEmpty ? null : keywords),
    ));
    return written > 0;
  }

  Future<int> createCard({
    required int subjectId,
    required String title,
    String content = '',
    CardKind kind = CardKind.text,
    String? sources,
  }) {
    final now = DateTime.now();
    return into(contextCards).insert(
      ContextCardsCompanion.insert(
        subjectId: subjectId,
        title: requiredText(title, maxCardTitleLength, 'title'),
        kind: kind,
        content: Value(content.trim()),
        sources: Value(sources),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// The card's links, as `encodeAnswerSources` stores them. Not an edit of
  /// what the AI reads, so the digest stays.
  Future<void> setCardSources(int id, String? sources) =>
      (update(contextCards)..where((t) => t.id.equals(id)))
          .write(ContextCardsCompanion(sources: Value(sources)));

  /// Appends page photos (stored paths) after the ones already there.
  Future<void> addCardImages(int cardId, List<String> paths) async {
    if (paths.isEmpty) return;
    final existing = await cardImagePaths(cardId);
    await batch((b) => b.insertAll(cardImages, [
          for (var i = 0; i < paths.length; i++)
            CardImagesCompanion.insert(
              cardId: cardId,
              path: paths[i],
              ord: Value(existing.length + i),
            ),
        ]));
  }

  Future<List<String>> cardImagePaths(int cardId) async {
    final rows = await (select(cardImages)
          ..where((t) => t.cardId.equals(cardId))
          ..orderBy([(t) => OrderingTerm.asc(t.ord), (t) => OrderingTerm.asc(t.id)]))
        .get();
    return [for (final r in rows) r.path];
  }

  /// A changed content invalidates the digest made from it; a changed title
  /// alone does not.
  Future<void> updateCard(
    int id, {
    required String title,
    required String content,
  }) async {
    final current = await (select(contextCards)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (current == null) return;
    final trimmed = content.trim();
    final changed = trimmed != current.content;
    await (update(contextCards)..where((t) => t.id.equals(id))).write(
      ContextCardsCompanion(
        title: Value(requiredText(title, maxCardTitleLength, 'title')),
        content: Value(trimmed),
        summary: changed ? const Value(null) : const Value.absent(),
        keywords: changed ? const Value(null) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteCard(int id) => transaction(() async {
        await (delete(meetingCards)..where((t) => t.cardId.equals(id))).go();
        await (delete(cardImages)..where((t) => t.cardId.equals(id))).go();
        await (delete(contextCards)..where((t) => t.id.equals(id))).go();
      });

  Future<void> markCardsUsed(Iterable<int> ids, DateTime at) {
    final list = ids.toList();
    if (list.isEmpty) return Future.value();
    return (update(contextCards)..where((t) => t.id.isIn(list)))
        .write(ContextCardsCompanion(lastUsedAt: Value(at)));
  }

  // -------------------------------------------------------------- lessons

  Stream<List<Meeting>> watchLessons(int subjectId) => (select(meetings)
        ..where((t) => t.subjectId.equals(subjectId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  /// Replaces the lesson's pinned set.
  Future<void> pinCards(int meetingId, Iterable<int> cardIds) =>
      transaction(() async {
        await (delete(meetingCards)..where((t) => t.meetingId.equals(meetingId)))
            .go();
        await batch((b) => b.insertAll(
              meetingCards,
              [
                for (final id in cardIds.toSet())
                  MeetingCardsCompanion.insert(meetingId: meetingId, cardId: id),
              ],
            ));
      });

  /// Pinned cards in the order they were last edited.
  Stream<List<ContextCard>> watchPinnedCards(int meetingId) {
    final query = select(contextCards).join([
      innerJoin(meetingCards, meetingCards.cardId.equalsExp(contextCards.id)),
    ])
      ..where(meetingCards.meetingId.equals(meetingId))
      ..orderBy([OrderingTerm.desc(contextCards.updatedAt)]);
    return query.map((row) => row.readTable(contextCards)).watch();
  }

  Future<List<int>> pinnedCardIds(int meetingId) async {
    final rows = await (select(meetingCards)
          ..where((t) => t.meetingId.equals(meetingId)))
        .get();
    return [for (final r in rows) r.cardId];
  }

  /// What the start sheet proposes: the cards pinned in this subject's most
  /// recent lesson. Respects an empty set — if the last lesson pinned nothing,
  /// nothing is proposed.
  Future<List<int>> lastPinnedCardIds(int subjectId) async {
    final last = await (select(meetings)
          ..where((t) => t.subjectId.equals(subjectId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (last == null) return const [];
    return pinnedCardIds(last.id);
  }

  /// The subject of the most recent recording, or null — the start sheet's
  /// preselection until the timetable exists.
  Future<int?> lastUsedSubjectId() async {
    final last = await (select(meetings)
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .getSingleOrNull();
    return last?.subjectId;
  }

  /// Sets or clears a meeting's subject. Pins that belong to another subject
  /// are dropped, so a lesson never carries cards it is not about.
  Future<void> setMeetingSubject(int meetingId, int? subjectId) =>
      transaction(() async {
        await (update(meetings)..where((t) => t.id.equals(meetingId)))
            .write(MeetingsCompanion(subjectId: Value(subjectId)));
        final foreign = selectOnly(contextCards)..addColumns([contextCards.id]);
        if (subjectId != null) {
          foreign.where(contextCards.subjectId.equals(subjectId).not());
        }
        await (delete(meetingCards)
              ..where((t) =>
                  t.meetingId.equals(meetingId) & t.cardId.isInQuery(foreign)))
            .go();
      });

  Future<void> setMeetingRules(int meetingId, String? rules) =>
      (update(meetings)..where((t) => t.id.equals(meetingId)))
          .write(MeetingsCompanion(rules: Value(_optional(rules))));

  static String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Trimmed and cut to [max] UTF-16 units — the unit drift's length check
/// counts in — without splitting a surrogate pair. Blank is an error: the UI
/// disables its save button for it, so reaching here blank is a bug.
String requiredText(String value, int max, String field) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, field, 'must not be blank');
  }
  if (trimmed.length <= max) return trimmed;

  final buffer = StringBuffer();
  var length = 0;
  for (final rune in trimmed.runes) {
    final units = rune > 0xFFFF ? 2 : 1;
    if (length + units > max) break;
    buffer.writeCharCode(rune);
    length += units;
  }
  return buffer.toString().trimRight();
}
