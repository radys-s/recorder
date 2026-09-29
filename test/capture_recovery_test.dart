import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recorder/audio/capture_watchdog.dart';
import 'package:recorder/audio/pcm_chunker.dart';
import 'package:recorder/audio/pending_audio.dart';
import 'package:recorder/core/paths.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/data/db/tables/upload_queue_table.dart';

const _bytesPerMs = 32;

Uint8List _pcm({required int ms, required int amplitude}) {
  final bytes = Uint8List(ms * _bytesPerMs);
  for (var i = 0; i < bytes.length ~/ 2; i++) {
    final sample = i.isEven ? amplitude : -amplitude;
    final unsigned = sample < 0 ? sample + 0x10000 : sample;
    bytes[i * 2] = unsigned & 0xFF;
    bytes[i * 2 + 1] = (unsigned >> 8) & 0xFF;
  }
  return bytes;
}

Uint8List _loud(int ms) => _pcm(ms: ms, amplitude: 6000);
Uint8List _silent(int ms) => _pcm(ms: ms, amplitude: 0);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('CaptureWatchdog', () {
    final t0 = DateTime(2026, 9, 29, 10);
    DateTime at(int s) => t0.add(Duration(seconds: s));

    test('healthy while bytes keep arriving', () {
      final w = CaptureWatchdog()..start(t0);
      for (var s = 1; s <= 30; s++) {
        w.onData(at(s));
        expect(w.check(at(s), paused: false), WatchdogVerdict.healthy);
      }
    });

    test('restarts after a stall, then gives up after too many in a row', () {
      final w = CaptureWatchdog()..start(t0);
      expect(w.check(at(2), paused: false), WatchdogVerdict.healthy);
      expect(w.check(at(3), paused: false), WatchdogVerdict.restart);
      // The restart gets its own grace period.
      expect(w.check(at(4), paused: false), WatchdogVerdict.healthy);
      expect(w.check(at(6), paused: false), WatchdogVerdict.restart);
      expect(w.check(at(9), paused: false), WatchdogVerdict.restart);
      expect(w.check(at(12), paused: false), WatchdogVerdict.giveUp);
    });

    test('paused time is never a stall', () {
      final w = CaptureWatchdog()..start(t0);
      for (var s = 1; s <= 120; s++) {
        expect(w.check(at(s), paused: true), WatchdogVerdict.healthy);
      }
      // Resuming right after a long pause is not an instant stall.
      expect(w.check(at(121), paused: false), WatchdogVerdict.healthy);
    });

    test('a stable stretch forgives earlier restarts', () {
      final w = CaptureWatchdog()..start(t0);
      expect(w.check(at(3), paused: false), WatchdogVerdict.restart);
      expect(w.restarts, 1);
      for (var s = 4; s <= 20; s++) {
        w.onData(at(s));
      }
      expect(w.restarts, 0);
    });
  });

  group('SilentMicDetector', () {
    test('needs ten seconds of exact silence', () {
      final d = SilentMicDetector();
      var changed = false;
      for (var i = 0; i < 99; i++) {
        changed = d.add(0.0);
      }
      expect(changed, isFalse);
      expect(d.silent, isFalse);
      expect(d.add(0.0), isTrue);
      expect(d.silent, isTrue);
    });

    test('a quiet room is not a dead mic, and sound clears the alert', () {
      final d = SilentMicDetector();
      for (var i = 0; i < 300; i++) {
        expect(d.add(0.003), isFalse);
      }
      expect(d.silent, isFalse);

      for (var i = 0; i < 100; i++) {
        d.add(0.0);
      }
      expect(d.silent, isTrue);
      expect(d.add(0.01), isTrue);
      expect(d.silent, isFalse);
    });
  });

  group('PcmChunker.snapshot', () {
    test('is null when nothing is buffered', () {
      final chunker = PcmChunker(onChunk: (_) {});
      expect(chunker.snapshot(), isNull);
    });

    test('holds everything not yet emitted, including a partial frame', () {
      final chunker = PcmChunker(onChunk: (_) {});
      final input = _loud(2050);
      // An odd number of bytes so a half sample and a partial frame are open.
      chunker.addBytes(Uint8List.sublistView(input, 0, input.length - 1));
      final snap = chunker.snapshot()!;
      expect(snap.sequence, 0);
      expect(snap.startMs, 0);
      expect(snap.bytes.length, input.length - 1);
    });

    test('continues the timeline where the last chunk ended', () {
      final chunks = <PcmChunk>[];
      final chunker = PcmChunker(onChunk: chunks.add);
      chunker.addBytes(_loud(20000));
      chunker.addBytes(_silent(2000));
      expect(chunks, isNotEmpty);

      final snap = chunker.snapshot();
      final last = chunks.last;
      if (snap != null) {
        // The snapshot is the next chunk: same clock, next sequence.
        expect(snap.sequence, last.sequence + 1);
        expect(snap.startMs, last.endMs);
      }
    });
  });

  group('pending audio', () {
    late Directory docs;
    late AppDatabase db;

    setUp(() {
      docs = Directory.systemTemp.createTempSync('pending_audio_test');
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    Future<int> meeting() => db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026, 9, 29)),
    );

    String dirOf(int id) => meetingRecordingsDir(docs.path, id);

    test('round-trips and trims a torn sample', () async {
      final dir = dirOf(1);
      final bytes = Uint8List.fromList(List.generate(101, (i) => i));
      await writePendingAudio(dir, sequence: 7, startMs: 4200, bytes: bytes);
      final read = (await readPendingAudio(dir))!;
      expect(read.sequence, 7);
      expect(read.startMs, 4200);
      expect(read.pcm.length, 100);
      expect(read.pcm.first, 0);
      // The temp file used for the atomic rename never lingers.
      expect(File('${pendingAudioPath(dir)}.tmp').existsSync(), isFalse);
    });

    test('ignores files that are not ours', () async {
      final dir = dirOf(1);
      Directory(dir).createSync(recursive: true);
      File(pendingAudioPath(dir)).writeAsBytesSync(List.filled(64, 9));
      expect(await readPendingAudio(dir), isNull);
      File(pendingAudioPath(dir)).writeAsBytesSync([1, 2, 3]);
      expect(await readPendingAudio(dir), isNull);
    });

    test('voicedMsOf counts only loud frames', () {
      final pcm = Uint8List.fromList([..._loud(1000), ..._silent(1500)]);
      expect(voicedMsOf(pcm), 1000);
    });

    test('recovery turns the snapshot into a queued chunk', () async {
      final id = await meeting();
      final dir = dirOf(id);
      await writePendingAudio(
        dir,
        sequence: 3,
        startMs: 90000,
        bytes: _loud(4000),
      );

      final recovered = await recoverPendingAudio(db: db, docsPath: docs.path);
      expect(recovered, [id]);

      final segments = await db.select(db.transcriptSegments).get();
      expect(segments, hasLength(1));
      final s = segments.single;
      expect(s.sequence, 3);
      expect(s.startMs, 90000);
      expect(s.endMs, 94000);
      expect(s.status, SegmentStatus.pending);
      expect(s.cutReason, 'recovered');
      expect(s.localAudioPath, 'recordings/meeting_$id/chunk_0003.wav');
      expect(File(p.join(dir, 'chunk_0003.wav')).existsSync(), isTrue);

      final queue = await db.select(db.uploadQueue).get();
      expect(queue, hasLength(1));
      expect(queue.single.status, QueueStatus.pending);
      expect(File(pendingAudioPath(dir)).existsSync(), isFalse);
    });

    test('silence is recovered as an empty segment, not uploaded', () async {
      final id = await meeting();
      await writePendingAudio(
        dirOf(id),
        sequence: 0,
        startMs: 0,
        bytes: _silent(3000),
      );
      await recoverPendingAudio(db: db, docsPath: docs.path);
      final segments = await db.select(db.transcriptSegments).get();
      expect(segments.single.status, SegmentStatus.transcribed);
      expect(await db.select(db.uploadQueue).get(), isEmpty);
    });

    test('a stale snapshot is deleted, not duplicated', () async {
      final id = await meeting();
      await db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: id,
          sequence: 3,
          startMs: 90000,
          endMs: 94000,
          status: SegmentStatus.transcribed,
          localAudioPath: 'recordings/meeting_$id/chunk_0003.wav',
          createdAt: DateTime(2026, 9, 29),
        ),
      );
      final dir = dirOf(id);
      await writePendingAudio(dir, sequence: 3, startMs: 90000, bytes: _loud(4000));

      final recovered = await recoverPendingAudio(db: db, docsPath: docs.path);
      expect(recovered, isEmpty);
      expect(await db.select(db.transcriptSegments).get(), hasLength(1));
      expect(File(pendingAudioPath(dir)).existsSync(), isFalse);
    });

    test('a snapshot too short to transcribe is dropped', () async {
      final id = await meeting();
      final dir = dirOf(id);
      await writePendingAudio(dir, sequence: 0, startMs: 0, bytes: _loud(200));
      expect(await recoverPendingAudio(db: db, docsPath: docs.path), isEmpty);
      expect(await db.select(db.transcriptSegments).get(), isEmpty);
      expect(File(pendingAudioPath(dir)).existsSync(), isFalse);
    });

    test('a folder of a deleted meeting is cleaned up', () async {
      final dir = dirOf(999);
      await writePendingAudio(dir, sequence: 0, startMs: 0, bytes: _loud(4000));
      expect(await recoverPendingAudio(db: db, docsPath: docs.path), isEmpty);
      expect(File(pendingAudioPath(dir)).existsSync(), isFalse);
    });

    test('no recordings folder at all is fine', () async {
      expect(await recoverPendingAudio(db: db, docsPath: docs.path), isEmpty);
    });
  });
}
