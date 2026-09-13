import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';

/// The meeting row itself, watched rather than read once so the title and the
/// "still running" state stay live while a recording is in progress.
final meetingProvider = StreamProvider.family<Meeting?, int>((ref, meetingId) {
  return ref.watch(appDatabaseProvider).meetingsDao.watchMeetingById(meetingId);
});

/// Segments in `sequence` order. This is the whole live-transcript mechanism:
/// the recorder inserts a row per chunk and the queue worker fills in its text
/// later, and both writes push a new list through this stream.
final meetingSegmentsProvider =
    StreamProvider.family<List<TranscriptSegment>, int>((ref, meetingId) {
  return ref
      .watch(appDatabaseProvider)
      .transcriptSegmentsDao
      .watchSegmentsForMeeting(meetingId);
});

/// The meeting's notes row, or null when none has been generated yet. Watched
/// rather than read so a generation started here shows its result without the
/// screen having to await anything.
final meetingNotesProvider =
    StreamProvider.family<MeetingNote?, int>((ref, meetingId) {
  return ref.watch(appDatabaseProvider).meetingNotesDao.watchForMeeting(meetingId);
});

/// Every answer card of a meeting, oldest first. One stream feeds both the
/// merged timeline cards and the pinned panel.
final answerCardsProvider =
    StreamProvider.family<List<AnswerCard>, int>((ref, meetingId) {
  return ref.watch(appDatabaseProvider).answerCardsDao.watchForMeeting(meetingId);
});
