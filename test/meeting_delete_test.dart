import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recorder/core/paths.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/meeting_notes_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/data/db/tables/upload_queue_table.dart';
import 'package:recorder/data/meeting_deleter.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime(2026, 9, 14, 10);

  /// A meeting with one of everything hanging off it.
  Future<int> seedMeeting(String title) async {
    final meetingId = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(title: title, createdAt: now),
    );
    final segmentId = await db.into(db.transcriptSegments).insert(
          TranscriptSegmentsCompanion.insert(
            meetingId: meetingId,
            sequence: 0,
            startMs: 0,
            endMs: 1000,
            status: SegmentStatus.transcribed,
            localAudioPath: 'recordings/meeting_$meetingId/chunk_0000.wav',
            createdAt: now,
          ),
        );
    await db.into(db.uploadQueue).insert(
          UploadQueueCompanion.insert(
            segmentId: segmentId,
            meetingId: meetingId,
            localFilePath: 'recordings/meeting_$meetingId/chunk_0000.wav',
            status: QueueStatus.succeeded,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.answerCards).insert(
          AnswerCardsCompanion.insert(
            meetingId: meetingId,
            segmentId: segmentId,
            question: 'Kolik?',
            answer: 'Hodně.',
            createdAt: now,
          ),
        );
    await db.into(db.meetingNotes).insert(
          MeetingNotesCompanion.insert(
            meetingId: meetingId,
            depth: NotesDepth.standard,
            model: 'test',
            status: NotesStatus.ready,
            content: const Value('- bod'),
            createdAt: now,
          ),
        );
    return meetingId;
  }

  Future<Map<String, List<int>>> meetingIdsByTable() async => {
        'meetings': [for (final r in await db.select(db.meetings).get()) r.id],
        'segments': [
          for (final r in await db.select(db.transcriptSegments).get())
            r.meetingId,
        ],
        'queue': [
          for (final r in await db.select(db.uploadQueue).get()) r.meetingId,
        ],
        'cards': [
          for (final r in await db.select(db.answerCards).get()) r.meetingId,
        ],
        'notes': [
          for (final r in await db.select(db.meetingNotes).get()) r.meetingId,
        ],
      };

  group('MeetingsDao.deleteMeeting', () {
    test('removes the meeting and everything under it, nothing else',
        () async {
      final gone = await seedMeeting('Smazat');
      final kept = await seedMeeting('Nechat');

      await db.meetingsDao.deleteMeeting(gone);

      expect(await meetingIdsByTable(), {
        'meetings': [kept],
        'segments': [kept],
        'queue': [kept],
        'cards': [kept],
        'notes': [kept],
      });
    });

    test('keeps saved notes, only forgetting the meeting', () async {
      final gone = await seedMeeting('Smazat');
      final kept = await seedMeeting('Nechat');
      final fromGone = await db.savedNotesDao
          .saveNote(title: 'A', content: 'a', meetingId: gone);
      final fromKept = await db.savedNotesDao
          .saveNote(title: 'B', content: 'b', meetingId: kept);

      await db.meetingsDao.deleteMeeting(gone);

      final notes = {
        for (final n in await db.select(db.savedNotes).get()) n.id: n,
      };
      expect(notes, hasLength(2));
      expect(notes[fromGone]!.meetingId, isNull);
      expect(notes[fromGone]!.content, 'a');
      expect(notes[fromKept]!.meetingId, kept);
    });
  });

  test('deleteOrphanRows clears rows a late write left behind', () async {
    final orphaned = await seedMeeting('Smazaná');
    final kept = await seedMeeting('Nechat');
    final saved = await db.savedNotesDao
        .saveNote(title: 'A', content: 'a', meetingId: orphaned);
    // What an in-flight chunk can leave: the meeting row gone, its children not.
    await (db.delete(db.meetings)..where((t) => t.id.equals(orphaned))).go();

    final removed = await db.meetingsDao.deleteOrphanRows();

    expect(removed, 4);
    expect(await meetingIdsByTable(), {
      'meetings': [kept],
      'segments': [kept],
      'queue': [kept],
      'cards': [kept],
      'notes': [kept],
    });
    final note = await (db.select(db.savedNotes)
          ..where((t) => t.id.equals(saved)))
        .getSingle();
    expect(note.meetingId, isNull);
    expect(await db.meetingsDao.deleteOrphanRows(), 0);
  });

  test('renameMeeting trims and rejects blank', () async {
    final id = await seedMeeting('Schůzka 14.09. 10:00');
    await db.meetingsDao.renameMeeting(id, '  Porada s Janem ');
    final meeting =
        await (db.select(db.meetings)..where((t) => t.id.equals(id)))
            .getSingle();
    expect(meeting.title, 'Porada s Janem');
    expect(() => db.meetingsDao.renameMeeting(id, '  '), throwsArgumentError);
  });

  group('MeetingDeleter', () {
    late Directory docs;

    setUp(() async {
      docs = await Directory.systemTemp.createTemp('recorder_delete_');
    });
    tearDown(() async {
      if (await docs.exists()) await docs.delete(recursive: true);
    });

    Future<File> chunk(int meetingId) async {
      final file = File(
        p.join(meetingRecordingsDir(docs.path, meetingId), 'chunk_0000.wav'),
      );
      await file.create(recursive: true);
      return file;
    }

    MeetingDeleter deleter({int? recording}) => MeetingDeleter(
          db.meetingsDao,
          isRecording: (id) => id == recording,
          documentsPath: () async => docs.path,
        );

    test('deletes the rows and the meeting\'s audio directory', () async {
      final gone = await seedMeeting('Smazat');
      final kept = await seedMeeting('Nechat');
      final goneFile = await chunk(gone);
      final keptFile = await chunk(kept);

      await deleter().delete(gone);

      expect((await meetingIdsByTable())['meetings'], [kept]);
      expect(await goneFile.parent.exists(), isFalse);
      expect(await keptFile.exists(), isTrue);
    });

    test('a meeting with no audio on disk still deletes', () async {
      final id = await seedMeeting('Bez zvuku');
      await deleter().delete(id);
      expect((await meetingIdsByTable())['meetings'], isEmpty);
    });

    test('refuses the meeting being recorded and touches nothing', () async {
      final id = await seedMeeting('Nahrává se');
      final file = await chunk(id);

      await expectLater(
        deleter(recording: id).delete(id),
        throwsStateError,
      );

      expect((await meetingIdsByTable())['meetings'], [id]);
      expect(await file.exists(), isTrue);
    });

    test('a failure to reach the audio is logged, not thrown', () async {
      final id = await seedMeeting('Smazat');
      final broken = MeetingDeleter(
        db.meetingsDao,
        isRecording: (_) => false,
        documentsPath: () async => throw const FileSystemException('nope'),
      );

      await broken.delete(id);

      expect((await meetingIdsByTable())['meetings'], isEmpty);
    });
  });
}
