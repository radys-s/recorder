import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meetings_table.dart';
import '../tables/transcript_segments_table.dart';

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
  });

  final Meeting meeting;
  final int segmentCount;
  final int transcribedCount;
  final int failedCount;

  /// End of the last chunk. A better duration than `endedAt - createdAt`,
  /// which also counts the moments spent starting and stopping.
  final int durationMs;

  /// Everything neither finished nor given up on: queued, uploading, or
  /// waiting out a backoff.
  int get outstandingCount => segmentCount - transcribedCount - failedCount;

  Duration get duration => Duration(milliseconds: durationMs);
}

@DriftAccessor(tables: [Meetings, TranscriptSegments])
class MeetingsDao extends DatabaseAccessor<AppDatabase> with _$MeetingsDaoMixin {
  MeetingsDao(super.db);

  Stream<List<Meeting>> watchAllMeetings() {
    return (select(meetings)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
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

    // Left outer: a meeting that was stopped before its first chunk closed
    // still has to appear, with zeroes.
    final query = select(meetings).join([
      leftOuterJoin(
        transcriptSegments,
        transcriptSegments.meetingId.equalsExp(meetings.id),
      ),
    ])
      ..addColumns([count, longest, transcribed, failed])
      ..groupBy([meetings.id])
      ..orderBy([OrderingTerm.desc(meetings.createdAt)]);

    return query.map((row) {
      return MeetingSummary(
        meeting: row.readTable(meetings),
        segmentCount: row.read(count) ?? 0,
        transcribedCount: row.read(transcribed) ?? 0,
        failedCount: row.read(failed) ?? 0,
        durationMs: row.read(longest) ?? 0,
      );
    }).watch();
  }

  Future<Meeting?> watchMeetingByIdOnce(int id) =>
      (select(meetings)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Meeting?> watchMeetingById(int id) =>
      (select(meetings)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> insertMeeting(MeetingsCompanion entry) => into(meetings).insert(entry);

  Future<void> markEnded(int id, DateTime endedAt) => (update(meetings)
        ..where((t) => t.id.equals(id)))
      .write(MeetingsCompanion(endedAt: Value(endedAt)));

  /// Closes meetings left open by a process that died mid-recording, and
  /// returns their ids.
  ///
  /// Safe to run only at startup, before anything can be recording: an open
  /// `endedAt` means "in progress" the rest of the time. The end time comes
  /// from the last chunk that made it to disk, so the duration reflects the
  /// audio actually kept rather than however long the app was open.
  Future<List<int>> closeOrphanedMeetings() async {
    final open =
        await (select(meetings)..where((t) => t.endedAt.isNull())).get();
    if (open.isEmpty) return const [];

    for (final meeting in open) {
      final lastChunk = transcriptSegments.createdAt.max();
      final row = await (selectOnly(transcriptSegments)
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
    return (delete(meetings)
          ..where((t) =>
              t.endedAt.isNotNull() &
              t.id.isNotInQuery(withSegments)))
        .go();
  }
}
