import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transcript_segments_table.dart';

part 'transcript_segments_dao.g.dart';

@DriftAccessor(tables: [TranscriptSegments])
class TranscriptSegmentsDao extends DatabaseAccessor<AppDatabase>
    with _$TranscriptSegmentsDaoMixin {
  TranscriptSegmentsDao(super.db);

  Stream<List<TranscriptSegment>> watchSegmentsForMeeting(int meetingId) {
    return (select(transcriptSegments)
          ..where((t) => t.meetingId.equals(meetingId))
          ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
        .watch();
  }

  /// One-shot read of the same rows [watchSegmentsForMeeting] streams, for
  /// callers outside the widget tree — the notes generator wants the transcript
  /// as it stands right now, not a subscription to it.
  Future<List<TranscriptSegment>> segmentsForMeeting(int meetingId) {
    return (select(transcriptSegments)
          ..where((t) => t.meetingId.equals(meetingId))
          ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
        .get();
  }

  Future<int> insertSegment(TranscriptSegmentsCompanion entry) =>
      into(transcriptSegments).insert(entry);

  Future<void> updateSegmentText(
    int id,
    String text,
    SegmentStatus status, {
    double? confidence,
    String? rawContent,
    String? sttEngine,
  }) => (update(transcriptSegments)..where((t) => t.id.equals(id))).write(
    TranscriptSegmentsCompanion(
      content: Value(text),
      status: Value(status),
      confidence: Value(confidence),
      rawContent: rawContent == null ? const Value.absent() : Value(rawContent),
      sttEngine: sttEngine == null ? const Value.absent() : Value(sttEngine),
    ),
  );

  /// Replaces text the user or the AI corrected, keeping what was heard
  /// first. A second correction keeps the first original.
  Future<void> correctSegment(int id, String text) => transaction(() async {
    final row = await segmentById(id);
    if (row == null || row.content == null || row.content == text) return;
    await (update(transcriptSegments)..where((t) => t.id.equals(id))).write(
      TranscriptSegmentsCompanion(
        content: Value(text),
        rawContent: Value(row.rawContent ?? row.content),
      ),
    );
  });

  /// Puts back what was heard.
  Future<void> restoreSegment(int id) => transaction(() async {
    final row = await segmentById(id);
    if (row == null || row.rawContent == null) return;
    await (update(transcriptSegments)..where((t) => t.id.equals(id))).write(
      TranscriptSegmentsCompanion(
        content: Value(row.rawContent),
        rawContent: const Value(null),
      ),
    );
  });

  Future<void> updateSegmentStatus(int id, SegmentStatus status) =>
      (update(transcriptSegments)..where((t) => t.id.equals(id))).write(
        TranscriptSegmentsCompanion(status: Value(status)),
      );

  /// Text of the nearest already-transcribed segment before [sequence].
  ///
  /// Fed to Whisper as its `prompt`, which biases it to continue the same
  /// sentence across a chunk boundary — the mitigation for the accepted
  /// mid-word cuts. Returns null when the previous chunk has not come back
  /// yet, in which case the request simply goes without context.
  Future<String?> previousTranscript(int meetingId, int sequence) async {
    final row =
        await (select(transcriptSegments)
              ..where(
                (t) =>
                    t.meetingId.equals(meetingId) &
                    t.sequence.isSmallerThanValue(sequence) &
                    t.content.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.sequence)])
              ..limit(1))
            .getSingleOrNull();
    return row?.content;
  }

  Future<TranscriptSegment?> segmentById(int id) => (select(
    transcriptSegments,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> nextSequenceForMeeting(int meetingId) async {
    final query = selectOnly(transcriptSegments)
      ..addColumns([transcriptSegments.sequence.max()])
      ..where(transcriptSegments.meetingId.equals(meetingId));
    final row = await query.getSingleOrNull();
    final maxSeq = row?.read(transcriptSegments.sequence.max());
    return (maxSeq ?? -1) + 1;
  }
}
