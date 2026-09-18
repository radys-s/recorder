import 'package:drift/drift.dart';

import '../../../core/constants.dart';
import '../../../stt/whisper_segment_filter.dart';
import '../app_database.dart';
import '../tables/answer_cards_table.dart';
import '../tables/chat_messages_table.dart';
import '../tables/context_cards_table.dart';
import '../tables/meeting_notes_table.dart';
import '../tables/meetings_table.dart';
import '../tables/refined_segments_table.dart';
import '../tables/saved_notes_table.dart';
import '../tables/subjects_table.dart';
import '../tables/transcript_segments_table.dart';
import '../tables/upload_queue_table.dart';

part 'meetings_dao.g.dart';

/// A meeting plus the counts the list screen needs, in one grouped query
/// rather than one query per row.
class MeetingSummary {
  const MeetingSummary({
    required this.meeting,
    required this.segmentCount,
    required this.transcribedCount,
    required this.failedCount,
    required this.durationMs,
    this.subject,
    this.importantCount = 0,
    this.scoredCount = 0,
    this.avgConfidence,
  });

  final Meeting meeting;

  /// The lesson's subject, or null for an ordinary meeting.
  final Subject? subject;
  final int segmentCount;
  final int transcribedCount;
  final int failedCount;

  /// End of the last chunk. A better duration than `endedAt - createdAt`,
  /// which also counts the moments spent starting and stopping.
  final int durationMs;

  /// Moments the student starred during the lesson.
  final int importantCount;

  /// Segments Whisper scored, and the mean of those scores. Both are needed:
  /// one badly heard chunk in a good lesson says nothing.
  final int scoredCount;
  final double? avgConfidence;

  /// True when the recording as a whole came back badly heard. Derived from
  /// the scores already stored per segment rather than from a column of its
  /// own, so it costs no migration and says something that was measured.
  bool get weakAudio =>
      scoredCount >= kWeakAudioMinScoredSegments &&
      avgConfidence != null &&
      avgConfidence! < kLowConfidenceLogprob;

  /// Everything neither finished nor given up on: queued, uploading, or
  /// waiting out a backoff.
  int get outstandingCount => segmentCount - transcribedCount - failedCount;

  Duration get duration => Duration(milliseconds: durationMs);
}

/// One finished meeting's audio, and whether anything still needs it.
class ClearableAudio {
  const ClearableAudio({
    required this.meetingId,
    required this.endedAt,
    required this.queueSettled,
    required this.refiningSettled,
  });

  final int meetingId;
  final DateTime endedAt;

  /// Every chunk has either been transcribed or given up on.
  final bool queueSettled;

  /// No refined window is still pending or running.
  final bool refiningSettled;
}

@DriftAccessor(
  tables: [
    Meetings,
    TranscriptSegments,
    UploadQueue,
    AnswerCards,
    MeetingNotes,
    SavedNotes,
    Subjects,
    MeetingCards,
    ChatMessages,
    RefinedSegments,
  ],
)
class MeetingsDao extends DatabaseAccessor<AppDatabase>
    with _$MeetingsDaoMixin {
  MeetingsDao(super.db);

  /// A one-shot read for code that only needs today's titles, not a stream.
  Future<List<Meeting>> allMeetingsOnce() => select(meetings).get();

  Stream<List<Meeting>> watchAllMeetings() {
    return (select(
      meetings,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// Newest first, with segment counts and duration. Watched, so a chunk
  /// landing mid-recording updates the row in place.
  Stream<List<MeetingSummary>> watchMeetingSummaries() {
    final count = transcriptSegments.id.count();
    final longest = transcriptSegments.endMs.max();
    final transcribed = transcriptSegments.id.count(
      filter: transcriptSegments.status.equalsValue(SegmentStatus.transcribed),
    );
    final failed = transcriptSegments.id.count(
      filter: transcriptSegments.status.equalsValue(SegmentStatus.failed),
    );
    final scored = transcriptSegments.confidence.count();
    final confidence = transcriptSegments.confidence.avg();
    // A correlated count rather than a third join, which would multiply the
    // segment rows and break every count above.
    final stars = subqueryExpression<int>(
      selectOnly(chatMessages)
        ..addColumns([chatMessages.id.count()])
        ..where(
          chatMessages.meetingId.equalsExp(meetings.id) &
              chatMessages.intent.equalsValue(ChatIntent.important),
        ),
    );

    // Left outer: a meeting that was stopped before its first chunk closed
    // still has to appear, with zeroes.
    final query =
        select(meetings).join([
            leftOuterJoin(
              transcriptSegments,
              transcriptSegments.meetingId.equalsExp(meetings.id),
            ),
            // One subject per meeting at most, so this join does not multiply rows.
            leftOuterJoin(subjects, subjects.id.equalsExp(meetings.subjectId)),
          ])
          ..addColumns([
            count,
            longest,
            transcribed,
            failed,
            stars,
            scored,
            confidence,
          ])
          ..groupBy([meetings.id])
          ..orderBy([OrderingTerm.desc(meetings.createdAt)]);

    return query.map((row) {
      return MeetingSummary(
        meeting: row.readTable(meetings),
        subject: row.readTableOrNull(subjects),
        segmentCount: row.read(count) ?? 0,
        transcribedCount: row.read(transcribed) ?? 0,
        failedCount: row.read(failed) ?? 0,
        durationMs: row.read(longest) ?? 0,
        importantCount: row.read(stars) ?? 0,
        scoredCount: row.read(scored) ?? 0,
        avgConfidence: row.read(confidence),
      );
    }).watch();
  }

  Future<Meeting?> watchMeetingByIdOnce(int id) =>
      (select(meetings)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Meeting?> watchMeetingById(int id) =>
      (select(meetings)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> insertMeeting(MeetingsCompanion entry) =>
      into(meetings).insert(entry);

  Future<void> markEnded(int id, DateTime endedAt) =>
      (update(meetings)..where((t) => t.id.equals(id))).write(
        MeetingsCompanion(endedAt: Value(endedAt)),
      );

  Future<void> renameMeeting(int id, String title) {
    final clean = title.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be blank');
    }
    return (update(meetings)..where((t) => t.id.equals(id))).write(
      MeetingsCompanion(title: Value(clean)),
    );
  }

  /// Removes a meeting and everything that hangs off it, in one transaction so
  /// a crash halfway cannot leave a transcript with no meeting above it.
  ///
  /// Saved notes are the exception: they are the user's copy and stay in the
  /// library, only forgetting which meeting they came from. The audio files
  /// are not the database's business — `MeetingDeleter` removes those after
  /// this commits.
  Future<void> deleteMeeting(int id) => transaction(() async {
    await (delete(uploadQueue)..where((t) => t.meetingId.equals(id))).go();
    await (delete(answerCards)..where((t) => t.meetingId.equals(id))).go();
    await (delete(meetingNotes)..where((t) => t.meetingId.equals(id))).go();
    await (delete(
      transcriptSegments,
    )..where((t) => t.meetingId.equals(id))).go();
    await (delete(meetingCards)..where((t) => t.meetingId.equals(id))).go();
    await (delete(chatMessages)..where((t) => t.meetingId.equals(id))).go();
    await (delete(refinedSegments)..where((t) => t.meetingId.equals(id))).go();
    await (update(savedNotes)..where((t) => t.meetingId.equals(id))).write(
      const SavedNotesCompanion(meetingId: Value(null)),
    );
    await (delete(meetings)..where((t) => t.id.equals(id))).go();
  });

  /// Rows whose meeting no longer exists, removed at startup.
  ///
  /// Deleting a meeting does not stop work already in flight for it: a chunk
  /// mid-upload finishes, its transcript write is a no-op on a deleted row, but
  /// the live-answer call it triggers can still insert a card afterwards. Safe
  /// only at startup, for the same reason as [closeOrphanedMeetings].
  /// Finished meetings that still have audio on disk, with what would be lost
  /// by deleting it: an upload still in flight, or a refined window still to
  /// be heard. One query rather than one per meeting, because this runs at
  /// startup.
  Future<List<ClearableAudio>> clearableAudio() {
    final unsettledUploads = subqueryExpression<int>(
      selectOnly(uploadQueue)
        ..addColumns([uploadQueue.id.count()])
        ..where(
          uploadQueue.meetingId.equalsExp(meetings.id) &
              uploadQueue.status.isNotIn([
                QueueStatus.succeeded.index,
                QueueStatus.failedPermanent.index,
              ]),
        ),
    );
    final unsettledWindows = subqueryExpression<int>(
      selectOnly(refinedSegments)
        ..addColumns([refinedSegments.id.count()])
        ..where(
          refinedSegments.meetingId.equalsExp(meetings.id) &
              refinedSegments.status.isNotIn([
                RefinedStatus.ready.index,
                RefinedStatus.failed.index,
              ]),
        ),
    );

    final query = selectOnly(meetings)
      ..addColumns([
        meetings.id,
        meetings.endedAt,
        unsettledUploads,
        unsettledWindows,
      ])
      ..where(meetings.endedAt.isNotNull() & meetings.audioClearedAt.isNull());

    return query
        .map(
          (row) => ClearableAudio(
            meetingId: row.read(meetings.id)!,
            endedAt: row.read(meetings.endedAt)!,
            queueSettled: (row.read(unsettledUploads) ?? 0) == 0,
            refiningSettled: (row.read(unsettledWindows) ?? 0) == 0,
          ),
        )
        .get();
  }

  Future<void> markAudioCleared(int meetingId, DateTime at) =>
      (update(meetings)..where((t) => t.id.equals(meetingId))).write(
        MeetingsCompanion(audioClearedAt: Value(at)),
      );

  Future<int> deleteOrphanRows() => transaction(() async {
    final existing = selectOnly(meetings)..addColumns([meetings.id]);
    var removed = 0;
    removed += await (delete(
      uploadQueue,
    )..where((t) => t.meetingId.isNotInQuery(existing))).go();
    removed += await (delete(
      answerCards,
    )..where((t) => t.meetingId.isNotInQuery(existing))).go();
    removed += await (delete(
      meetingNotes,
    )..where((t) => t.meetingId.isNotInQuery(existing))).go();
    removed += await (delete(
      transcriptSegments,
    )..where((t) => t.meetingId.isNotInQuery(existing))).go();
    removed += await (delete(
      chatMessages,
    )..where((t) => t.meetingId.isNotInQuery(existing))).go();
    removed += await (delete(
      refinedSegments,
    )..where((t) => t.meetingId.isNotInQuery(existing))).go();
    await (delete(
      meetingCards,
    )..where((t) => t.meetingId.isNotInQuery(existing))).go();
    await (update(savedNotes)..where(
          (t) => t.meetingId.isNotNull() & t.meetingId.isNotInQuery(existing),
        ))
        .write(const SavedNotesCompanion(meetingId: Value(null)));
    return removed;
  });

  /// Closes meetings left open by a process that died mid-recording, and
  /// returns their ids.
  ///
  /// Safe to run only at startup, before anything can be recording: an open
  /// `endedAt` means "in progress" the rest of the time. The end time comes
  /// from the last chunk that made it to disk, so the duration reflects the
  /// audio actually kept rather than however long the app was open.
  Future<List<int>> closeOrphanedMeetings() async {
    final open = await (select(
      meetings,
    )..where((t) => t.endedAt.isNull())).get();
    if (open.isEmpty) return const [];

    for (final meeting in open) {
      final lastChunk = transcriptSegments.createdAt.max();
      final row =
          await (selectOnly(transcriptSegments)
                ..addColumns([lastChunk])
                ..where(transcriptSegments.meetingId.equals(meeting.id)))
              .getSingleOrNull();

      await (update(meetings)..where((t) => t.id.equals(meeting.id))).write(
        MeetingsCompanion(
          endedAt: Value(row?.read(lastChunk) ?? meeting.createdAt),
          interrupted: const Value(true),
        ),
      );
    }

    return open.map((m) => m.id).toList();
  }

  /// Meetings with no audio at all — a Record tap that was undone a second
  /// later. Cleared at startup so the list is not littered with empty rows.
  Future<int> deleteEmptyMeetings() async {
    final withSegments = selectOnly(transcriptSegments, distinct: true)
      ..addColumns([transcriptSegments.meetingId]);
    return (delete(meetings)..where(
          (t) => t.endedAt.isNotNull() & t.id.isNotInQuery(withSegments),
        ))
        .go();
  }
}
