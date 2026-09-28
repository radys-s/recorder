import 'package:drift/drift.dart';

import '../../../learning/scheduler.dart';
import '../../../stt/transcript_sanitizer.dart';
import '../app_database.dart';
import '../tables/study_cards_table.dart';

part 'study_cards_dao.g.dart';

/// A question and answer before it is stored.
class StudyItem {
  const StudyItem(this.front, this.back, this.source);

  final String front;
  final String back;
  final StudySource source;

  @override
  bool operator ==(Object other) =>
      other is StudyItem &&
      other.front == front &&
      other.back == back &&
      other.source == source;

  @override
  int get hashCode => Object.hash(front, back, source);

  @override
  String toString() => 'StudyItem($front → $back)';
}

/// Cards per subject for the subject screen.
class StudyStats {
  const StudyStats({required this.total, required this.due});

  final int total;
  final int due;
}

/// The first moment of the day after [now]: everything due before it is
/// „dnes".
DateTime endOfStudyDay(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);

@DriftAccessor(tables: [StudyCards])
class StudyCardsDao extends DatabaseAccessor<AppDatabase>
    with _$StudyCardsDaoMixin {
  StudyCardsDao(super.db);

  static const int maxFrontLength = 300;
  static const int maxBackLength = 1200;

  static String keyFor(String front) => normalizeForArtifactMatch(front);

  Expression<bool> _due(StudyCards t, DateTime before, int? subjectId) {
    var e = t.suspended.equals(false) & t.dueAt.isSmallerThanValue(before);
    if (subjectId != null) e = e & t.subjectId.equals(subjectId);
    return e;
  }

  /// Cards due before the end of [now]'s day, across subjects or in one.
  Stream<int> watchDueCount(DateTime now, {int? subjectId}) {
    final count = studyCards.id.count();
    return (selectOnly(studyCards)
          ..addColumns([count])
          ..where(_due(studyCards, endOfStudyDay(now), subjectId)))
        .map((r) => r.read(count) ?? 0)
        .watchSingle();
  }

  Stream<StudyStats> watchStats(int subjectId, DateTime now) =>
      (select(
        studyCards,
      )..where((t) => t.subjectId.equals(subjectId))).watch().map((rows) {
        final end = endOfStudyDay(now);
        return StudyStats(
          total: rows.length,
          due: rows.where((c) => !c.suspended && c.dueAt.isBefore(end)).length,
        );
      });

  /// The review queue: due cards, oldest due first.
  Future<List<StudyCard>> dueCards(DateTime now, {int? subjectId}) =>
      (select(studyCards)
            ..where((t) => _due(t, endOfStudyDay(now), subjectId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.dueAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Stream<List<StudyCard>> watchCards(int subjectId) =>
      (select(studyCards)
            ..where((t) => t.subjectId.equals(subjectId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch();

  /// Stores [items], skipping a question the subject already has (compared
  /// without case and diacritics) and anything empty. New cards are due at
  /// once. Returns how many were added.
  Future<int> addCards(
    int subjectId,
    Iterable<StudyItem> items, {
    int? meetingId,
    int? noteId,
    required DateTime now,
  }) => transaction(() async {
    final taken = {
      for (final row
          in await (selectOnly(studyCards)
                ..addColumns([studyCards.frontKey])
                ..where(studyCards.subjectId.equals(subjectId)))
              .get())
        row.read(studyCards.frontKey)!,
    };
    var added = 0;
    for (final item in items) {
      final front = _clip(item.front, maxFrontLength);
      final back = _clip(item.back, maxBackLength);
      final key = keyFor(front);
      if (front.isEmpty || back.isEmpty || key.isEmpty) continue;
      if (!taken.add(key)) continue;
      await into(studyCards).insert(
        StudyCardsCompanion.insert(
          subjectId: subjectId,
          meetingId: Value(meetingId),
          noteId: Value(noteId),
          front: front,
          back: back,
          frontKey: key,
          source: item.source,
          dueAt: now,
          createdAt: now,
        ),
      );
      added++;
    }
    return added;
  });

  Future<void> applyReview(int id, ReviewOutcome outcome) =>
      (update(studyCards)..where((t) => t.id.equals(id))).write(
        StudyCardsCompanion(
          ease: Value(outcome.state.ease),
          intervalDays: Value(outcome.state.intervalDays),
          reps: Value(outcome.state.reps),
          lapses: Value(outcome.state.lapses),
          dueAt: Value(outcome.dueAt),
        ),
      );

  /// Edits the text. A question that now matches another card of the subject
  /// throws, rather than leaving two identical cards.
  Future<void> updateCard(
    int id, {
    required String front,
    required String back,
  }) async {
    final f = _clip(front, maxFrontLength);
    final b = _clip(back, maxBackLength);
    if (f.isEmpty || b.isEmpty) {
      throw ArgumentError('Otázka i odpověď musí něco obsahovat.');
    }
    await (update(studyCards)..where((t) => t.id.equals(id))).write(
      StudyCardsCompanion(
        front: Value(f),
        back: Value(b),
        frontKey: Value(keyFor(f)),
      ),
    );
  }

  Future<void> setSuspended(int id, bool suspended) =>
      (update(studyCards)..where((t) => t.id.equals(id))).write(
        StudyCardsCompanion(suspended: Value(suspended)),
      );

  Future<void> deleteCard(int id) =>
      (delete(studyCards)..where((t) => t.id.equals(id))).go();

  /// Puts back a card deleted a moment ago, schedule included.
  Future<void> restore(StudyCard card) =>
      into(studyCards).insert(card, mode: InsertMode.insertOrReplace);

  static String _clip(String s, int max) {
    final t = s.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
    return t.length <= max ? t : t.substring(0, max).trimRight();
  }
}
