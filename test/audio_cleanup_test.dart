import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recorder/data/audio_cleaner.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/meetings_dao.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/refined_segments_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/data/db/tables/upload_queue_table.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  final ended = DateTime(2026, 9, 10, 9, 45);

  ClearableAudio settled({DateTime? at}) => ClearableAudio(
    meetingId: 1,
    endedAt: at ?? ended,
    queueSettled: true,
    refiningSettled: true,
  );

  group('canClearAudio', () {
    test('a settled lesson goes once its retention has run out', () {
      expect(
        canClearAudio(
          meeting: settled(),
          retention: AudioRetention.sevenDays,
          now: ended.add(const Duration(days: 7, minutes: 1)),
        ),
        isTrue,
      );
    });

    test('the retention boundary itself is not yet due', () {
      // A minute short of seven days: the student may still be waiting for a
      // pass that only starts when they open the lesson.
      expect(
        canClearAudio(
          meeting: settled(),
          retention: AudioRetention.sevenDays,
          now: ended
              .add(const Duration(days: 7))
              .subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('„nikdy" never deletes, however old the lesson is', () {
      expect(
        canClearAudio(
          meeting: settled(),
          retention: AudioRetention.never,
          now: ended.add(const Duration(days: 900)),
        ),
        isFalse,
      );
    });

    test('a chunk still queued for upload keeps the whole lesson', () {
      final meeting = ClearableAudio(
        meetingId: 1,
        endedAt: ended,
        queueSettled: false,
        refiningSettled: true,
      );
      expect(
        canClearAudio(
          meeting: meeting,
          retention: AudioRetention.oneDay,
          now: ended.add(const Duration(days: 30)),
        ),
        isFalse,
      );
    });

    test('a refined window still to be re-heard keeps it too', () {
      final meeting = ClearableAudio(
        meetingId: 1,
        endedAt: ended,
        queueSettled: true,
        refiningSettled: false,
      );
      expect(
        canClearAudio(
          meeting: meeting,
          retention: AudioRetention.oneDay,
          now: ended.add(const Duration(days: 30)),
        ),
        isFalse,
      );
    });
  });

  group('formatBytes', () {
    test('reads in the unit a person thinks in', () {
      expect(formatBytes(512), '512 B');
      // Kilobytes get no decimal: nobody reads „2.0 kB" as more precise.
      expect(formatBytes(2048), '2 kB');
      expect(formatBytes(85 * 1024 * 1024), '85 MB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    });
  });

  group('AudioCleaner', () {
    late AppDatabase db;
    late Directory docs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      docs = await Directory.systemTemp.createTemp('recorder_audio_test');
    });

    tearDown(() async {
      await db.close();
      if (docs.existsSync()) await docs.delete(recursive: true);
    });

    AudioCleaner cleanerFor({bool Function(int)? isRecording}) => AudioCleaner(
      db.meetingsDao,
      db.preferencesDao,
      documentsPath: () async => docs.path,
      isRecording: isRecording,
    );

    /// A finished lesson with one chunk on disk, settled unless told otherwise.
    Future<int> seed(
      String title, {
      required DateTime endedAt,
      QueueStatus queue = QueueStatus.succeeded,
      RefinedStatus? refined,
      int bytes = 4096,
    }) async {
      final id = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(title: title, createdAt: endedAt),
      );
      await db.meetingsDao.markEnded(id, endedAt);
      final path = 'recordings/meeting_$id/chunk_0000.wav';
      final segmentId = await db
          .into(db.transcriptSegments)
          .insert(
            TranscriptSegmentsCompanion.insert(
              meetingId: id,
              sequence: 0,
              startMs: 0,
              endMs: 20000,
              status: SegmentStatus.transcribed,
              localAudioPath: path,
              createdAt: endedAt,
            ),
          );
      await db
          .into(db.uploadQueue)
          .insert(
            UploadQueueCompanion.insert(
              segmentId: segmentId,
              meetingId: id,
              localFilePath: path,
              status: queue,
              createdAt: endedAt,
              updatedAt: endedAt,
            ),
          );
      if (refined != null) {
        await db
            .into(db.refinedSegments)
            .insert(
              RefinedSegmentsCompanion.insert(
                meetingId: id,
                windowIndex: 0,
                startMs: 0,
                endMs: 20000,
                engine: RefinedEngine.whisper,
                status: refined,
                createdAt: endedAt,
              ),
            );
      }
      final file = File(p.join(docs.path, path));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.filled(bytes, 0));
      return id;
    }

    test('an old settled lesson loses its audio and is marked', () async {
      final id = await seed(
        'Stará',
        endedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(await cleanerFor().sweep(), 1);
      expect(
        Directory(p.join(docs.path, 'recordings', 'meeting_$id')).existsSync(),
        isFalse,
      );
      final meeting = await db.meetingsDao.watchMeetingByIdOnce(id);
      expect(meeting!.audioClearedAt, isNotNull);
    });

    test('yesterday\'s lesson is kept on the default seven days', () async {
      await seed(
        'Včerejší',
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(await cleanerFor().sweep(), 0);
    });

    test('an unsettled upload survives even „Uvolnit místo teď"', () async {
      await seed(
        'Nedodělaná',
        endedAt: DateTime.now().subtract(const Duration(days: 30)),
        queue: QueueStatus.pending,
      );
      expect(await cleanerFor().sweep(force: true), 0);
    });

    test('a running refined window survives it as well', () async {
      await seed(
        'Vylepšuje se',
        endedAt: DateTime.now().subtract(const Duration(days: 30)),
        refined: RefinedStatus.running,
      );
      expect(await cleanerFor().sweep(force: true), 0);
    });

    test('„Uvolnit místo teď" waives only the waiting', () async {
      await seed('Dnešní', endedAt: DateTime.now());
      expect(await cleanerFor().sweep(), 0);
      expect(await cleanerFor().sweep(force: true), 1);
    });

    test('„nikdy" stops the sweep, but not the button', () async {
      await db.preferencesDao.setAudioRetention(AudioRetention.never);
      await seed(
        'Archivní',
        endedAt: DateTime.now().subtract(const Duration(days: 300)),
      );
      expect(await cleanerFor().sweep(), 0);
      expect(await cleanerFor().sweep(force: true), 1);
    });

    test('the lesson being recorded is never touched', () async {
      final id = await seed(
        'Probíhá',
        endedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      final cleaner = cleanerFor(isRecording: (m) => m == id);
      expect(await cleaner.sweep(), 0);
    });

    test(
      'sizes report the biggest lesson first, and skip empty ones',
      () async {
        final small = await seed('Malá', endedAt: DateTime.now(), bytes: 1000);
        final big = await seed('Velká', endedAt: DateTime.now(), bytes: 9000);
        // A cleared lesson leaves no directory and must not be listed.
        final gone = await seed('Smazaná', endedAt: DateTime.now(), bytes: 500);
        await Directory(p.join(docs.path, 'recordings', 'meeting_$gone'))
            .delete(recursive: true);

        final sizes = await cleanerFor().sizes();
        expect(sizes.map((s) => s.meetingId), [big, small]);
        expect(sizes.first.title, 'Velká');
        expect(sizes.first.bytes, 9000);
      },
    );
  });
}
