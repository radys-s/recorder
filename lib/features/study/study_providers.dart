import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/daos/study_cards_dao.dart';

final studyCardsDaoProvider = Provider<StudyCardsDao>((ref) {
  return ref.watch(appDatabaseProvider).studyCardsDao;
});

/// Injectable clock for the study screens; tests pin it to a fixed day.
final studyClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Cards due today, in every subject (null) or one.
final dueStudyCountProvider = StreamProvider.family<int, int?>((
  ref,
  subjectId,
) {
  final now = ref.watch(studyClockProvider)();
  return ref
      .watch(studyCardsDaoProvider)
      .watchDueCount(now, subjectId: subjectId);
});

final studyStatsProvider = StreamProvider.family<StudyStats, int>((
  ref,
  subjectId,
) {
  final now = ref.watch(studyClockProvider)();
  return ref.watch(studyCardsDaoProvider).watchStats(subjectId, now);
});

final subjectStudyCardsProvider = StreamProvider.family<List<StudyCard>, int>((
  ref,
  subjectId,
) {
  return ref.watch(studyCardsDaoProvider).watchCards(subjectId);
});
