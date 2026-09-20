import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/answer_cards_table.dart';

part 'answer_cards_dao.g.dart';

@DriftAccessor(tables: [AnswerCards])
class AnswerCardsDao extends DatabaseAccessor<AppDatabase>
    with _$AnswerCardsDaoMixin {
  AnswerCardsDao(super.db);

  /// Every card of a meeting, oldest first.
  ///
  /// One stream serves both places cards appear — merged into the timeline and
  /// pinned as the newest answer — because a second query for "the newest
  /// undismissed one" would be a second subscription over the same handful of
  /// rows.
  Stream<List<AnswerCard>> watchForMeeting(int meetingId) {
    return (select(answerCards)
          ..where((t) => t.meetingId.equals(meetingId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  Future<int> insertCard(AnswerCardsCompanion entry) =>
      into(answerCards).insert(entry);

  /// Inserts at most one automatic answer for a transcript segment.
  ///
  /// The live-answer callback is intentionally fire-and-forget. A retry or a
  /// delayed completion must therefore not put the same teacher question in
  /// the timeline twice. Keeping this check and insert in one transaction is
  /// the smallest protection that still works across overlapping callbacks.
  Future<({int id, bool inserted})> insertCardIfAbsentForSegment(
    AnswerCardsCompanion entry,
  ) {
    return transaction(() async {
      final existing =
          await (select(answerCards)
                ..where((t) => t.segmentId.equals(entry.segmentId.value)))
              .getSingleOrNull();
      if (existing != null) return (id: existing.id, inserted: false);
      final id = await into(answerCards).insert(entry);
      return (id: id, inserted: true);
    });
  }

  Future<void> dismiss(int id) =>
      (update(answerCards)..where((t) => t.id.equals(id))).write(
        const AnswerCardsCompanion(dismissed: Value(true)),
      );
}
