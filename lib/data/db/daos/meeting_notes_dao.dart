import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meeting_notes_table.dart';
import '../tables/preferences_table.dart';

part 'meeting_notes_dao.g.dart';

@DriftAccessor(tables: [MeetingNotes])
class MeetingNotesDao extends DatabaseAccessor<AppDatabase>
    with _$MeetingNotesDaoMixin {
  MeetingNotesDao(super.db);

  Stream<MeetingNote?> watchForMeeting(int meetingId) {
    return (select(meetingNotes)..where((t) => t.meetingId.equals(meetingId)))
        .watchSingleOrNull();
  }

  Future<MeetingNote?> forMeeting(int meetingId) {
    return (select(meetingNotes)..where((t) => t.meetingId.equals(meetingId)))
        .getSingleOrNull();
  }

  /// Claims the row for a generation that is about to start.
  ///
  /// [content] is deliberately left alone: while a regenerate is running the
  /// previous notes stay readable, and if it fails they are still there.
  Future<void> markGenerating(
    int meetingId,
    NotesDepth depth,
    String model,
  ) async {
    await into(meetingNotes).insert(
      MeetingNotesCompanion.insert(
        meetingId: meetingId,
        depth: depth,
        model: model,
        status: NotesStatus.generating,
        createdAt: DateTime.now(),
      ),
      onConflict: DoUpdate(
        (_) => MeetingNotesCompanion(
          depth: Value(depth),
          model: Value(model),
          status: const Value(NotesStatus.generating),
          error: const Value(null),
          createdAt: Value(DateTime.now()),
        ),
        target: [meetingNotes.meetingId],
      ),
    );
  }

  Future<void> markReady(int meetingId, String content) =>
      (update(meetingNotes)..where((t) => t.meetingId.equals(meetingId))).write(
        MeetingNotesCompanion(
          content: Value(content),
          status: const Value(NotesStatus.ready),
          error: const Value(null),
          createdAt: Value(DateTime.now()),
        ),
      );

  Future<void> markFailed(int meetingId, String error) =>
      (update(meetingNotes)..where((t) => t.meetingId.equals(meetingId))).write(
        MeetingNotesCompanion(
          status: const Value(NotesStatus.failed),
          error: Value(error),
        ),
      );

  /// Reopens rows left mid-generation by an app kill. Called at startup next to
  /// the orphaned-meeting cleanup: without it the notes tab would sit on a
  /// spinner forever, waiting for a generation that died with the process.
  Future<int> failInterruptedGenerations() {
    return (update(meetingNotes)
          ..where((t) => t.status.equalsValue(NotesStatus.generating)))
        .write(
      const MeetingNotesCompanion(
        status: Value(NotesStatus.failed),
        error: Value('Aplikace se zavřela během generování.'),
      ),
    );
  }
}
