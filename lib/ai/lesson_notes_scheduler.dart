import 'dart:async';

import 'package:drift/drift.dart';

import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/meeting_notes_table.dart';
import '../data/db/tables/preferences_table.dart';

/// What to do about a lesson's výpisky right now.
enum NotesPlan {
  /// The lesson is still being recorded; its material is not complete.
  notEnded,

  /// Notes made after the lesson ended are already there.
  upToDate,

  /// A generation is running.
  busy,

  /// Nothing, a failure, or notes made from a lesson that has grown since.
  generate,
}

/// Decides from the two timestamps alone, so the rule can be tested without a
/// database: notes are only ever made from a *finished* lesson, and notes made
/// before [endedAt] (while the recording ran) are stale by definition.
NotesPlan planNotes({required DateTime? endedAt, MeetingNote? existing}) {
  if (endedAt == null) return NotesPlan.notEnded;
  if (existing == null) return NotesPlan.generate;
  if (existing.status == NotesStatus.generating) return NotesPlan.busy;
  if (existing.status == NotesStatus.ready &&
      !existing.createdAt.isBefore(endedAt)) {
    return NotesPlan.upToDate;
  }
  return NotesPlan.generate;
}

/// Makes a lesson's výpisky once — after it ended, after its refined pass and
/// after its chunks have all been heard — and again after a restart that
/// interrupted it.
///
/// The refined pass used to hand over notes while the lesson was still being
/// recorded; they were made from the first four minutes and never replaced.
class LessonNotesScheduler {
  LessonNotesScheduler(
    this._db, {
    required this.generate,
    this.announce,
    this.pollEvery = const Duration(seconds: 20),
    this.maxWait = const Duration(minutes: 15),
    this.restartWindow = const Duration(days: 3),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _tag = 'notes.scheduler';

  final AppDatabase _db;

  /// Runs the generation; never throws (see [NotesGenerator.generate]).
  final Future<void> Function(int meetingId, NotesDepth depth) generate;

  /// Tells the student their výpisky are ready: called with the lesson and its
  /// subject name, only for a lesson and only when the notes landed.
  final Future<void> Function(int meetingId, String subjectName)? announce;

  /// How often to look at the upload queue while chunks are still waiting, and
  /// how long to wait for them before making notes from what there is.
  final Duration pollEvery;
  final Duration maxWait;

  /// A lesson older than this is not retried at launch.
  final Duration restartWindow;
  final DateTime Function() _now;

  /// Lessons being waited for or generated, so a second trigger is a no-op.
  final Set<int> _active = {};

  /// Called when a lesson's refined pass has settled. Completes when the notes
  /// are made (or it was decided they need not be); callers do not await it.
  Future<void> onMeetingReady(int meetingId) async {
    if (!_active.add(meetingId)) return;
    try {
      var waited = Duration.zero;
      while (true) {
        final meeting = await _db.meetingsDao.watchMeetingByIdOnce(meetingId);
        if (meeting == null) return;
        final existing = await _db.meetingNotesDao.forMeeting(meetingId);
        final plan = planNotes(endedAt: meeting.endedAt, existing: existing);
        if (plan != NotesPlan.generate) return;

        // Chunks still waiting for a transcript would be missing from the
        // notes when the refined pass fell back to the live text. A rate limit
        // can rest the queue for ten minutes; past [maxWait] go on without.
        final unsettled = await _db.uploadQueueDao.unsettledForMeeting(
          meetingId,
        );
        if (unsettled > 0 && waited < maxWait) {
          await Future<void>.delayed(pollEvery);
          waited += pollEvery;
          continue;
        }

        final depth =
            existing?.depth ?? (await _db.preferencesDao.current()).notesDepth;
        AppLog.d(
          _tag,
          'meeting $meetingId: generating ${depth.name} notes'
          '${existing == null ? '' : ' (replacing ${existing.status.name})'}',
        );
        await generate(meetingId, depth);
        await _announce(meetingId, meeting.subjectId);
        return;
      }
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: notes step failed', e, st);
    } finally {
      _active.remove(meetingId);
    }
  }

  /// Notes for lessons a restart caught in between: ended recently, with a
  /// subject, and notes missing, failed or older than the end of the lesson.
  /// [skip] holds meetings whose refined pass is about to report on its own.
  Future<void> resumePending({Set<int> skip = const {}}) async {
    try {
      final cutoff = _now().subtract(restartWindow);
      final meetings =
          await (_db.select(_db.meetings)
                ..where(
                  (t) =>
                      t.endedAt.isNotNull() &
                      t.subjectId.isNotNull() &
                      t.endedAt.isBiggerOrEqualValue(cutoff),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.endedAt)]))
              .get();
      final pending = (await _db.refinedSegmentsDao.meetingsWithPending())
          .toSet();
      for (final m in meetings) {
        if (skip.contains(m.id) || pending.contains(m.id)) continue;
        final existing = await _db.meetingNotesDao.forMeeting(m.id);
        if (planNotes(endedAt: m.endedAt, existing: existing) !=
            NotesPlan.generate) {
          continue;
        }
        unawaited(onMeetingReady(m.id));
      }
    } catch (e, st) {
      AppLog.e(_tag, 'could not resume notes', e, st);
    }
  }

  Future<void> _announce(int meetingId, int? subjectId) async {
    final announce = this.announce;
    if (announce == null || subjectId == null) return;
    try {
      final notes = await _db.meetingNotesDao.forMeeting(meetingId);
      if (notes?.status != NotesStatus.ready) return;
      final subject = await _db.subjectsDao.subject(subjectId);
      if (subject == null) return;
      await announce(meetingId, subject.name);
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: announcing notes failed', e, st);
    }
  }
}
