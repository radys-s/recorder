import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/refined_segments_table.dart';

part 'refined_segments_dao.g.dart';

@DriftAccessor(tables: [RefinedSegments])
class RefinedSegmentsDao extends DatabaseAccessor<AppDatabase>
    with _$RefinedSegmentsDaoMixin {
  RefinedSegmentsDao(super.db);

  SimpleSelectStatement<$RefinedSegmentsTable, RefinedSegment> _forMeeting(
    int meetingId,
  ) =>
      select(refinedSegments)
        ..where((t) => t.meetingId.equals(meetingId))
        ..orderBy([(t) => OrderingTerm.asc(t.windowIndex)]);

  Stream<List<RefinedSegment>> watchForMeeting(int meetingId) =>
      _forMeeting(meetingId).watch();

  Future<List<RefinedSegment>> windows(int meetingId) =>
      _forMeeting(meetingId).get();

  Future<RefinedSegment?> window(int id) =>
      (select(refinedSegments)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Throws away the meeting's windows and plans new ones, in one step so the
  /// transcript never shows a half-replaced set.
  Future<void> replaceWindows(
    int meetingId,
    List<({int startMs, int endMs, RefinedEngine engine})> planned,
  ) =>
      transaction(() async {
        await (delete(refinedSegments)
              ..where((t) => t.meetingId.equals(meetingId)))
            .go();
        final now = DateTime.now();
        for (var i = 0; i < planned.length; i++) {
          await into(refinedSegments).insert(
            RefinedSegmentsCompanion.insert(
              meetingId: meetingId,
              windowIndex: i,
              startMs: planned[i].startMs,
              endMs: planned[i].endMs,
              engine: planned[i].engine,
              status: RefinedStatus.pending,
              createdAt: now,
            ),
          );
        }
      });

  /// Adds windows after the ones the meeting already has, keeping their text.
  ///
  /// This is how a pass that runs during the lesson grows: everything already
  /// transcribed stays, and only the audio nobody has re-heard yet is planned.
  Future<void> addWindows(
    int meetingId,
    List<({int startMs, int endMs, RefinedEngine engine})> planned,
  ) =>
      transaction(() async {
        if (planned.isEmpty) return;
        final existing = await _forMeeting(meetingId).get();
        var index = existing.isEmpty
            ? 0
            : existing.map((w) => w.windowIndex).reduce((a, b) => a > b ? a : b) + 1;
        final now = DateTime.now();
        for (final w in planned) {
          await into(refinedSegments).insert(
            RefinedSegmentsCompanion.insert(
              meetingId: meetingId,
              windowIndex: index++,
              startMs: w.startMs,
              endMs: w.endMs,
              engine: w.engine,
              status: RefinedStatus.pending,
              createdAt: now,
            ),
          );
        }
      });

  Future<void> markRunning(int id) => _write(
        id,
        const RefinedSegmentsCompanion(
          status: Value(RefinedStatus.running),
          error: Value(null),
        ),
      );

  Future<void> markReady(int id, String text, RefinedEngine engine) => _write(
        id,
        RefinedSegmentsCompanion(
          content: Value(text),
          rawContent: const Value(null),
          engine: Value(engine),
          status: const Value(RefinedStatus.ready),
          error: const Value(null),
        ),
      );

  /// A corrected window text; the first original is kept.
  Future<void> correctWindow(int id, String text) => transaction(() async {
        final row = await window(id);
        if (row == null || row.content == null || row.content == text) return;
        await _write(
          id,
          RefinedSegmentsCompanion(
            content: Value(text),
            rawContent: Value(row.rawContent ?? row.content),
          ),
        );
      });

  Future<void> restoreWindow(int id) => transaction(() async {
        final row = await window(id);
        if (row == null || row.rawContent == null) return;
        await _write(
          id,
          RefinedSegmentsCompanion(
            content: Value(row.rawContent),
            rawContent: const Value(null),
          ),
        );
      });

  Future<void> markFailed(int id, String error) => _write(
        id,
        RefinedSegmentsCompanion(
          status: const Value(RefinedStatus.failed),
          error: Value(error),
        ),
      );

  Future<void> markPending(int id) => _write(
        id,
        const RefinedSegmentsCompanion(
          status: Value(RefinedStatus.pending),
          error: Value(null),
        ),
      );

  Future<void> _write(int id, RefinedSegmentsCompanion row) =>
      (update(refinedSegments)..where((t) => t.id.equals(id))).write(row);

  /// A window cannot still be running when the app has only just started, so
  /// such rows go back to pending and are picked up again.
  Future<int> resetRunning() =>
      (update(refinedSegments)
            ..where((t) => t.status.equalsValue(RefinedStatus.running)))
          .write(const RefinedSegmentsCompanion(
        status: Value(RefinedStatus.pending),
      ));

  /// Meetings with a window still to do, oldest first.
  Future<List<int>> meetingsWithPending() async {
    final query = selectOnly(refinedSegments, distinct: true)
      ..addColumns([refinedSegments.meetingId])
      ..where(refinedSegments.status.equalsValue(RefinedStatus.pending))
      ..orderBy([OrderingTerm.asc(refinedSegments.meetingId)]);
    final rows = await query.get();
    return [for (final r in rows) r.read(refinedSegments.meetingId)!];
  }
}
