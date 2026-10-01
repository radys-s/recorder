import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/lesson_notes_scheduler.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/meeting_notes_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/refined_segments_table.dart';
import 'package:recorder/data/db/tables/upload_queue_table.dart';

final _end = DateTime(2026, 10, 1, 9, 45);

MeetingNote _note(NotesStatus status, DateTime createdAt) => MeetingNote(
  id: 1,
  meetingId: 1,
  depth: NotesDepth.standard,
  content: status == NotesStatus.ready ? 'x' : null,
  model: 'm',
  status: status,
  createdAt: createdAt,
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('planNotes', () {
    test('never while the lesson is still recording', () {
      expect(planNotes(endedAt: null), NotesPlan.notEnded);
      expect(
        planNotes(endedAt: null, existing: _note(NotesStatus.ready, _end)),
        NotesPlan.notEnded,
      );
    });

    test('a finished lesson without notes gets them', () {
      expect(planNotes(endedAt: _end), NotesPlan.generate);
    });

    test('notes made before the lesson ended are stale', () {
      final early = _end.subtract(const Duration(minutes: 40));
      expect(
        planNotes(endedAt: _end, existing: _note(NotesStatus.ready, early)),
        NotesPlan.generate,
      );
    });

    test('notes made after the end stand, also at the very same instant', () {
      expect(
        planNotes(endedAt: _end, existing: _note(NotesStatus.ready, _end)),
        NotesPlan.upToDate,
      );
      expect(
        planNotes(
          endedAt: _end,
          existing: _note(
            NotesStatus.ready,
            _end.add(const Duration(minutes: 3)),
          ),
        ),
        NotesPlan.upToDate,
      );
    });

    test('a running generation is left alone, a failed one is retried', () {
      expect(
        planNotes(endedAt: _end, existing: _note(NotesStatus.generating, _end)),
        NotesPlan.busy,
      );
      expect(
        planNotes(endedAt: _end, existing: _note(NotesStatus.failed, _end)),
        NotesPlan.generate,
      );
    });
  });

  group('LessonNotesScheduler', () {
    late AppDatabase db;
    late List<(int, NotesDepth)> generated;
    late List<(int, String)> announced;
    late LessonNotesScheduler scheduler;
    final notesAt = _end.add(const Duration(minutes: 1));

    Future<void> setCreatedAt(int meetingId, DateTime at) =>
        (db.update(db.meetingNotes)..where((t) => t.meetingId.equals(meetingId)))
            .write(MeetingNotesCompanion(createdAt: Value(at)));

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      generated = [];
      announced = [];
      scheduler = LessonNotesScheduler(
        db,
        // Stands in for the generator: stores ready notes dated after the end.
        generate: (id, depth) async {
          generated.add((id, depth));
          await db.meetingNotesDao.markGenerating(id, depth, 'm');
          await db.meetingNotesDao.markReady(id, 'výpisky');
          await setCreatedAt(id, notesAt);
        },
        announce: (id, name) async => announced.add((id, name)),
        pollEvery: const Duration(milliseconds: 5),
        maxWait: const Duration(milliseconds: 60),
        now: () => _end.add(const Duration(hours: 1)),
      );
    });
    tearDown(() => db.close());

    Future<int> lesson({DateTime? endedAt, bool subject = true}) async {
      final subjectId = subject
          ? await db.savedNotesDao.createFolder('Počítačové sítě')
          : null;
      return db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: DateTime(2026, 10, 1, 9),
          endedAt: Value(endedAt),
          subjectId: Value(subjectId),
        ),
      );
    }

    Future<void> queueRow(int meetingId, QueueStatus status) =>
        db.into(db.uploadQueue).insert(
          UploadQueueCompanion.insert(
            segmentId: 1,
            meetingId: meetingId,
            localFilePath: 'x.wav',
            status: status,
            createdAt: _end,
            updatedAt: _end,
          ),
        );

    test('does nothing while the lesson is recording', () async {
      final id = await lesson(endedAt: null);
      await scheduler.onMeetingReady(id);
      expect(generated, isEmpty);
    });

    test('makes notes once the lesson ended, at the preferred depth, and says so',
        () async {
      final id = await lesson(endedAt: _end);
      await scheduler.onMeetingReady(id);
      expect(generated, [(id, NotesDepth.standard)]);
      expect(announced, [(id, 'Počítačové sítě')]);
    });

    test('replaces notes made mid-lesson and keeps the student depth',
        () async {
      final id = await lesson(endedAt: _end);
      await db.meetingNotesDao.markGenerating(id, NotesDepth.full, 'm');
      await db.meetingNotesDao.markReady(id, 'ze čtyř minut');
      await setCreatedAt(id, _end.subtract(const Duration(minutes: 40)));

      await scheduler.onMeetingReady(id);

      expect(generated, [(id, NotesDepth.full)]);
      final stored = await db.meetingNotesDao.forMeeting(id);
      expect(stored!.createdAt, notesAt);
    });

    test('leaves notes made after the end alone', () async {
      final id = await lesson(endedAt: _end);
      await db.meetingNotesDao.markGenerating(id, NotesDepth.brief, 'm');
      await db.meetingNotesDao.markReady(id, 'hotovo');
      await setCreatedAt(id, _end);
      await scheduler.onMeetingReady(id);
      expect(generated, isEmpty);
    });

    test('waits for chunks still being transcribed, then goes on', () async {
      final id = await lesson(endedAt: _end);
      await queueRow(id, QueueStatus.failedRetryable);
      final done = scheduler.onMeetingReady(id);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(generated, isEmpty, reason: 'one chunk is still waiting');

      await (db.update(db.uploadQueue)..where((t) => t.meetingId.equals(id)))
          .write(
            const UploadQueueCompanion(status: Value(QueueStatus.succeeded)),
          );
      await done;
      expect(generated.length, 1);
    });

    test('gives up waiting after maxWait rather than never making notes',
        () async {
      final id = await lesson(endedAt: _end);
      await queueRow(id, QueueStatus.pending);
      await scheduler.onMeetingReady(id);
      expect(generated.length, 1);
    });

    test('a parked chunk does not hold the notes back', () async {
      final id = await lesson(endedAt: _end);
      await queueRow(id, QueueStatus.failedPermanent);
      await scheduler.onMeetingReady(id);
      expect(generated.length, 1);
    });

    test('two triggers for one lesson make one set of notes', () async {
      final id = await lesson(endedAt: _end);
      await Future.wait([
        scheduler.onMeetingReady(id),
        scheduler.onMeetingReady(id),
      ]);
      expect(generated.length, 1);
    });

    test('a meeting without a subject is not announced', () async {
      final id = await lesson(endedAt: _end, subject: false);
      await scheduler.onMeetingReady(id);
      expect(generated.length, 1);
      expect(announced, isEmpty);
    });

    test('resumePending picks up lessons a restart interrupted', () async {
      final missing = await lesson(endedAt: _end);
      final failed = await lesson(endedAt: _end);
      await db.meetingNotesDao.markGenerating(failed, NotesDepth.brief, 'm');
      await db.meetingNotesDao.markFailed(failed, 'chyba');
      final done = await lesson(endedAt: _end);
      await db.meetingNotesDao.markGenerating(done, NotesDepth.brief, 'm');
      await db.meetingNotesDao.markReady(done, 'ok');
      await setCreatedAt(done, _end.add(const Duration(minutes: 5)));
      final running = await lesson(endedAt: null);
      final old = await lesson(endedAt: _end.subtract(const Duration(days: 10)));

      await scheduler.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect({for (final g in generated) g.$1}, {missing, failed});
      expect(generated.map((g) => g.$1), isNot(contains(running)));
      expect(generated.map((g) => g.$1), isNot(contains(old)));
    });

    test('resumePending leaves lessons whose second pass will report',
        () async {
      final waiting = await lesson(endedAt: _end);
      final skipped = await lesson(endedAt: _end);
      await db.refinedSegmentsDao.replaceWindows(waiting, [
        (startMs: 0, endMs: 1000, engine: RefinedEngine.whisper),
      ]);

      await scheduler.resumePending(skip: {skipped});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(generated, isEmpty);
    });
  });
}
