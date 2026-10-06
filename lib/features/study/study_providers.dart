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

/// Cards one lesson's výpisky produced, with how many are due today.
final lessonStudyStatsProvider = StreamProvider.family<StudyStats, int>((
  ref,
  meetingId,
) {
  final now = ref.watch(studyClockProvider)();
  return ref.watch(studyCardsDaoProvider).watchLessonStats(meetingId, now);
});

/// Per lesson of a subject: its cards and how many are due. Lessons without
/// cards are not in the map.
final subjectLessonStudyProvider =
    StreamProvider.family<Map<int, StudyStats>, int>((ref, subjectId) {
      final now = ref.watch(studyClockProvider)();
      return ref.watch(studyCardsDaoProvider).watchLessonCounts(subjectId, now);
    });

/// When the next card after today falls due, for the „co dál" rows. Null when
/// nothing is scheduled.
final studyNextDueProvider = FutureProvider.autoDispose
    .family<DateTime?, ({int? subjectId, int? meetingId})>((ref, scope) {
      final now = ref.watch(studyClockProvider)();
      return ref
          .watch(studyCardsDaoProvider)
          .nextDueAfterToday(
            now,
            subjectId: scope.subjectId,
            meetingId: scope.meetingId,
          );
    });
