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

  Future<void> dismiss(int id) =>
      (update(answerCards)..where((t) => t.id.equals(id)))
          .write(const AnswerCardsCompanion(dismissed: Value(true)));
}
