import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/data/db/tables/upload_queue_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/audio/wav_writer.dart';
import 'package:recorder/data/recovery_backup.dart';

void main() {
  late Directory root;
  late Directory documents;
  late AppDatabase db;
  late File zip;
  late String audioPath;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aftermind_recovery_test_');
    documents = await Directory(p.join(root.path, 'original')).create();
    zip = File(p.join(root.path, 'backup.zip'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db
        .into(db.meetings)
        .insert(
          MeetingsCompanion.insert(
            title: 'Syntetická hodina',
            createdAt: DateTime(2026, 10, 6),
            endedAt: Value(DateTime(2026, 10, 6, 10)),
          ),
        );
    final audio = File(
      p.join(documents.path, 'recordings', 'meeting_$id', 'chunk_0000.wav'),
    );
    await audio.parent.create(recursive: true);
    // A valid PCM container; byte equality still does not prove native playback.
    final pcm = List.generate(96000, (i) => i % 256);
    await writeWavFile(
      path: audio.path,
      pcmFrames: [pcm],
      pcmByteLength: pcm.length,
    );
    audioPath = audio.path;
    final segmentId = await db
        .into(db.transcriptSegments)
        .insert(
          TranscriptSegmentsCompanion.insert(
            meetingId: id,
            sequence: 0,
            startMs: 0,
            endMs: 3000,
            localAudioPath: audioPath,
            status: SegmentStatus.transcribed,
            content: const Value('Pouze syntetický přepis.'),
            createdAt: DateTime(2026, 10, 6),
          ),
        );
    await db
        .into(db.uploadQueue)
        .insert(
          UploadQueueCompanion.insert(
            segmentId: segmentId,
            meetingId: id,
            localFilePath: audioPath,
            status: QueueStatus.pending,
            createdAt: DateTime(2026, 10, 6),
            updatedAt: DateTime(2026, 10, 6),
          ),
        );
    final photo = File(
      p.join(documents.path, 'photos', 'meeting_$id', 'page.jpg'),
    );
    await photo.parent.create(recursive: true);
    await photo.writeAsBytes([2, 4, 6, 8]);
    await db.chatMessagesDao.addPhotoMessage(
      meetingId: id,
      imagePath: photo.path,
      atMs: 0,
    );
    await db.meetingNotesDao.markGenerating(
      id,
      NotesDepth.standard,
      'synthetic',
    );
    await db.meetingNotesDao.markReady(id, '- Pouze syntetické výpisky.');
    await File(p.join(audio.parent.path, '_pending.wav'))
        .writeAsBytes([1, 2, 3]);
    // Credentials and unrelated files must not be copied from documents.
    await File(p.join(documents.path, 'unrelated-private-file.txt'))
        .writeAsString('not an asset');
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<File> backup() => RecoveryBackup.create(
    documents: documents,
    destination: zip,
    snapshotTo: (path) => db.customStatement('VACUUM INTO ?', [path]),
  );

  test(
    'snapshot, audio and photos survive restoration in another container',
    () async {
      await backup();
      // Optional, explicitly requested synthetic fixture for the standalone
      // CLI check. Ordinary tests never retain data outside their temp folder.
      final fixture = Platform.environment['AFTERMIND_SYNTHETIC_BACKUP'];
      if (fixture != null) {
        expect(await File(fixture).exists(), isFalse);
        await File(fixture).parent.create(recursive: true);
        await zip.copy(fixture);
      }
      final restored = Directory(p.join(root.path, 'different-container'));
      await RecoveryBackup.restore(backup: zip, destination: restored);
      final reopened = AppDatabase.forTesting(
        NativeDatabase(File(p.join(restored.path, 'recorder.sqlite'))),
      );
      try {
        final lesson = (await reopened.select(reopened.meetings).get()).single;
        expect(lesson.title, 'Syntetická hodina');
        final segment =
            (await reopened.select(reopened.transcriptSegments).get()).single;
        expect(segment.content, 'Pouze syntetický přepis.');
        expect(
          (await reopened.select(reopened.meetingNotes).get()).single.content,
          '- Pouze syntetické výpisky.',
        );
        expect(
          await File(
            p.join(restored.path, 'recordings', 'meeting_1', '_pending.wav'),
          ).readAsBytes(),
          [1, 2, 3],
        );
        expect(p.isAbsolute(segment.localAudioPath), isFalse);
        expect(
          await File(p.join(restored.path, segment.localAudioPath))
              .readAsBytes(),
          await File(audioPath).readAsBytes(),
        );
        final queue =
            (await reopened.select(reopened.uploadQueue).get()).single;
        expect(queue.localFilePath, segment.localAudioPath);
        final photo =
            (await reopened.select(reopened.chatMessages).get()).single;
        expect(
          await File(p.join(restored.path, photo.imagePath!)).readAsBytes(),
          [2, 4, 6, 8],
        );
        expect(
          await File(p.join(restored.path, 'unrelated-private-file.txt'))
              .exists(),
          isFalse,
        );
        // Export must not mutate the original DB or consume its queue.
        expect(
          (await db.select(db.transcriptSegments).get()).single.localAudioPath,
          audioPath,
        );
        expect(await db.select(db.uploadQueue).get(), hasLength(1));
      } finally {
        await reopened.close();
      }
    },
  );

  test('an existing destination is never overwritten', () async {
    await backup();
    final target = await Directory(p.join(root.path, 'existing')).create();
    final marker = await File(p.join(target.path, 'keep.txt'))
        .writeAsString('keep');
    await expectLater(
      RecoveryBackup.restore(backup: zip, destination: target),
      throwsFormatException,
    );
    expect(await marker.readAsString(), 'keep');
    await expectLater(backup(), throwsFormatException);
  });

  test(
    'missing referenced audio refuses publication of an incomplete backup',
    () async {
      await File(audioPath).delete();
      await expectLater(backup(), throwsFormatException);
      expect(await zip.exists(), isFalse);
    },
  );

  test(
    'intentionally cleared audio remains cleared, not falsely recoverable',
    () async {
      await File(audioPath).delete();
      await db.customStatement('UPDATE meetings SET audio_cleared_at = 1');
      await backup();
      final target = Directory(p.join(root.path, 'cleared'));
      await RecoveryBackup.restore(backup: zip, destination: target);
      expect(await target.exists(), isTrue);
    },
  );

  test('wrong checksum leaves no partly restored destination', () async {
    await backup();
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final manifest = jsonDecode(
      utf8.decode(archive.find('manifest.json')!.readBytes()!),
    ) as Map;
    (manifest['files']['recorder.sqlite'] as Map)['sha256'] = 'wrong';
    archive.add(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    await zip.writeAsBytes(ZipEncoder().encode(archive));
    final target = Directory(p.join(root.path, 'corrupt'));
    await expectLater(
      RecoveryBackup.restore(backup: zip, destination: target),
      throwsFormatException,
    );
    expect(await target.exists(), isFalse);
    expect(await File(audioPath).exists(), isTrue);
  });

  test(
    'a missing input never leaves a restoration staging directory',
    () async {
      final target = Directory(p.join(root.path, 'missing'));
      await expectLater(
        RecoveryBackup.restore(backup: zip, destination: target),
        throwsA(isA<FileSystemException>()),
      );
      expect(await target.exists(), isFalse);
      expect(
        await root
            .list()
            .where((e) => p.basename(e.path).startsWith('aftermind-restore-'))
            .toList(),
        isEmpty,
      );
    },
  );

  for (final name in [
    '../escape.txt',
    'recordings/../../escape.txt',
    'recordings/.. /escape.txt',
    'recordings\\escape.txt',
    '/absolute.txt',
  ]) {
    test('unsafe archive path is refused: $name', () async {
      final malicious = Archive()..add(ArchiveFile.string(name, 'synthetic'));
      await zip.writeAsBytes(ZipEncoder().encode(malicious));
      final target = Directory(p.join(root.path, 'unsafe'));
      await expectLater(
        RecoveryBackup.restore(backup: zip, destination: target),
        throwsFormatException,
      );
      expect(await target.exists(), isFalse);
      expect(await File(p.join(root.path, 'escape.txt')).exists(), isFalse);
    });
  }
}
