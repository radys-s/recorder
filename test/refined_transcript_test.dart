import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/audio/wav_concat.dart';
import 'package:recorder/audio/wav_writer.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/refined_segments_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/features/meeting_detail/timeline.dart';
import 'package:recorder/queue/refined_transcript_service.dart';
import 'package:recorder/stt/refined_transcriber.dart';
import 'package:recorder/stt/refined_transcript.dart';
import 'package:recorder/stt/stt_provider.dart';

final _t0 = DateTime(2026, 9, 16, 9);

TranscriptSegment _seg(
  int id,
  int startS,
  int endS, {
  String? text,
  int? voicedMs,
  int? sequence,
}) =>
    TranscriptSegment(
      id: id,
      meetingId: 1,
      sequence: sequence ?? id,
      startMs: startS * 1000,
      endMs: endS * 1000,
      content: text,
      status: SegmentStatus.transcribed,
      localAudioPath: 'recordings/meeting_1/chunk_$id.wav',
      createdAt: _t0,
      voicedMs: voicedMs,
    );

RefinedSegment _win(
  int id,
  int startS,
  int endS, {
  String? text,
  RefinedStatus status = RefinedStatus.ready,
}) =>
    RefinedSegment(
      id: id,
      meetingId: 1,
      windowIndex: id,
      startMs: startS * 1000,
      endMs: endS * 1000,
      content: text,
      engine: RefinedEngine.gemini,
      status: status,
      createdAt: _t0,
    );

/// 16 kHz mono PCM16 with every sample at [value].
Uint8List _pcm(int samples, int value) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, value, Endian.little);
  }
  return data.buffer.asUint8List();
}

class _FakeTranscriber implements RefinedTranscriber {
  final geminiCalls = <File>[];
  final whisperCalls = <File>[];
  final contexts = <RefinedContext>[];
  Object? Function(int call)? geminiResult;
  Object? Function(int call)? whisperResult;

  Future<String> _answer(Object? Function(int)? result, int call) async {
    final r = result?.call(call) ?? 'text';
    if (r is Exception) throw r;
    return r as String;
  }

  @override
  Future<String> viaGemini(File wav, RefinedContext context) {
    expect(wav.existsSync(), isTrue);
    geminiCalls.add(wav);
    contexts.add(context);
    return _answer(geminiResult, geminiCalls.length);
  }

  @override
  Future<String> viaWhisper(
    File wav,
    RefinedContext context, {
    required int? voicedMs,
    required int durationMs,
  }) {
    whisperCalls.add(wav);
    contexts.add(context);
    return _answer(whisperResult, whisperCalls.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('planWindows', () {
    test('closes a window once it reaches the target', () {
      final plans = planWindows(
        [for (var i = 0; i < 10; i++) _seg(i, i * 30, (i + 1) * 30)],
        target: const Duration(minutes: 2),
        minLast: const Duration(seconds: 30),
      );
      expect([for (final w in plans) w.chunks.length], [4, 4, 2]);
      expect(plans[1].startMs, plans[0].endMs);
    });

    test('a short last window joins the previous one', () {
      final plans = planWindows(
        [for (var i = 0; i < 9; i++) _seg(i, i * 30, (i + 1) * 30)],
        target: const Duration(minutes: 2),
      );
      expect([for (final w in plans) w.chunks.length], [4, 5]);
      expect(plans.last.endMs, 270000);
    });

    test('includes chunks the live pass skipped, in sequence order', () {
      final plans = planWindows(
        [
          _seg(2, 20, 30, text: 'b'),
          _seg(1, 10, 20, voicedMs: 0),
          _seg(0, 0, 10, text: 'a'),
        ],
        target: const Duration(minutes: 5),
      );
      expect(plans.single.chunks.map((s) => s.id), [0, 1, 2]);
    });

    test('during the lesson the unfinished tail is left alone', () {
      final plans = planWindows(
        [for (var i = 0; i < 10; i++) _seg(i, i * 30, (i + 1) * 30)],
        target: const Duration(minutes: 2),
        includeTail: false,
      );
      // The last two chunks are still being added to; only full windows go.
      expect([for (final w in plans) w.chunks.length], [4, 4]);
      expect(plans.last.endMs, 240000);
      expect(
        planWindows(
          [for (var i = 0; i < 3; i++) _seg(i, i * 30, (i + 1) * 30)],
          target: const Duration(minutes: 2),
          includeTail: false,
        ),
        isEmpty,
      );
    });

    test('nothing recorded, nothing planned', () {
      expect(planWindows(const [], target: const Duration(minutes: 4)), isEmpty);
    });
  });

  group('refinedOrLive', () {
    final live = [
      _seg(0, 0, 10, text: 'živě jedna'),
      _seg(1, 10, 20, text: 'živě dva'),
      _seg(2, 20, 30, text: 'živě tři'),
    ];

    test('a ready window replaces the live text it covers', () {
      expect(
        refinedOrLiveTranscript(live, [_win(0, 0, 20, text: 'lepší')]),
        'lepší živě tři',
      );
    });

    test('pending and failed windows fall back to live', () {
      expect(
        refinedOrLiveTranscript(live, [
          _win(0, 0, 20, text: 'x', status: RefinedStatus.pending),
          _win(1, 20, 30, status: RefinedStatus.failed),
        ]),
        'živě jedna živě dva živě tři',
      );
    });

    test('an empty ready window does not hide live text', () {
      expect(
        refinedOrLiveTranscript(live, [_win(0, 0, 30, text: '')]),
        'živě jedna živě dva živě tři',
      );
    });
  });

  group('withRefinedWindows', () {
    test('window in place of its segments, cards keep following', () {
      final segs = [
        _seg(0, 0, 10, text: 'a'),
        _seg(1, 10, 20, text: 'b'),
        _seg(2, 20, 30, text: 'c'),
      ];
      final card = AnswerCard(
        id: 7,
        meetingId: 1,
        segmentId: 1,
        question: 'q',
        answer: 'a',
        basis: 'meeting',
        dismissed: false,
        createdAt: _t0,
      );
      final merged = mergeTimeline(segs, [card], const []);
      final out = withRefinedWindows(merged, segs, [
        _win(0, 0, 20, text: 'AB'),
        _win(1, 20, 30, status: RefinedStatus.failed),
      ]);
      expect(out.map((o) => switch (o) {
            RefinedSegment(:final id, :final status) => 'w$id:${status.name}',
            TranscriptSegment(:final id) => 's$id',
            AnswerCard() => 'card',
            _ => '?',
          }), ['w0:ready', 'card', 'w1:failed', 's2']);
    });

    test('a window over skipped silence still shows, in time order', () {
      final all = [
        _seg(0, 0, 10, text: 'a'),
        _seg(1, 10, 20, voicedMs: 0),
        _seg(2, 20, 30, text: 'c'),
      ];
      final visible = [all[0], all[2]];
      final out = withRefinedWindows(
        mergeTimeline(visible, const [], const []),
        all,
        [_win(0, 10, 20, text: 'tichý učitel')],
      );
      expect(out.map((o) => o is RefinedSegment ? 'w' : 's'), ['s', 'w', 's']);
    });
  });

  group('wav', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('refined_wav'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('parseWav walks an 18-byte fmt chunk', () {
      final pcm = _pcm(4, 1000);
      final bytes = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(_u32(4 + 26 + 8 + pcm.length))
        ..add('WAVE'.codeUnits)
        ..add('fmt '.codeUnits)
        ..add(_u32(18))
        ..add(_u16(1))
        ..add(_u16(1))
        ..add(_u32(16000))
        ..add(_u32(32000))
        ..add(_u16(2))
        ..add(_u16(16))
        ..add(_u16(0))
        ..add('data'.codeUnits)
        ..add(_u32(pcm.length))
        ..add(pcm);
      final wav = parseWav(bytes.toBytes());
      expect(wav.sampleRate, 16000);
      expect(wav.pcm, pcm);
    });

    test('parseWav rejects a file without data', () {
      expect(() => parseWav(Uint8List.fromList('RIFF0000WAVE'.codeUnits)),
          throwsA(isA<WavFormatException>()));
    });

    test('concat joins the readable chunks and skips missing ones', () async {
      final a = p.join(dir.path, 'a.wav');
      final b = p.join(dir.path, 'b.wav');
      await writeWavFile(
          path: a, pcmFrames: [_pcm(1600, 3000)], pcmByteLength: 3200);
      await writeWavFile(
          path: b, pcmFrames: [_pcm(800, 3000)], pcmByteLength: 1600);
      final out = p.join(dir.path, 'out.wav');
      final result = await concatWavFiles(
        inputs: [a, p.join(dir.path, 'missing.wav'), b],
        outputPath: out,
      );
      expect(result.chunks, 2);
      expect(result.pcmBytes, 4800);
      expect(parseWav(File(out).readAsBytesSync()).pcm.length, 4800);
    });
  });

  group('cleanGeminiTranscript', () {
    test('silence marker becomes nothing', () {
      expect(cleanGeminiTranscript(' [ticho] '), '');
    });

    test('fences and wrapping quotes are dropped', () {
      expect(cleanGeminiTranscript('```\n„Dobrý den.“\n```'), 'Dobrý den.');
    });

    test('prompt carries the context and the previous tail', () {
      final messages = refinedGeminiMessages(RefinedContext(
        subjectName: 'Čeština',
        cardTitles: const ['Babička'],
        previousText: 'x' * 800,
      ));
      final user = messages.last.content;
      expect(user, contains('Subject: Čeština'));
      expect(user, contains('Topics: Babička'));
      expect(user, contains('…${'x' * 500}'));
      expect(user, isNot(contains('x' * 501)));
    });
  });

  group('RefinedTranscriptService', () {
    late AppDatabase db;
    late Directory dir;
    late _FakeTranscriber transcriber;
    var geminiKey = true;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dir = Directory.systemTemp.createTempSync('refined_service');
      transcriber = _FakeTranscriber();
      geminiKey = true;
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    RefinedTranscriptService service() => RefinedTranscriptService(
          db,
          transcriber,
          hasGeminiKey: () async => geminiKey,
          resolvePath: (stored) async => p.join(dir.path, stored),
          tempDir: () async => dir,
          retryDelays: const [Duration.zero],
        );

    /// Writes [count] more 30-second chunks, starting at sequence [from].
    Future<void> addChunks(
      int meetingId,
      int count, {
      int from = 0,
      int voicedMs = 20000,
    }) async {
      for (var i = from; i < from + count; i++) {
        final name = 'chunk_$i.wav';
        await writeWavFile(
          path: p.join(dir.path, name),
          pcmFrames: [_pcm(1600, 2000)],
          pcmByteLength: 3200,
        );
        await db.into(db.transcriptSegments).insert(
              TranscriptSegmentsCompanion.insert(
                meetingId: meetingId,
                sequence: i,
                startMs: i * 30000,
                endMs: (i + 1) * 30000,
                status: SegmentStatus.transcribed,
                localAudioPath: name,
                createdAt: _t0,
                content: Value('živě $i'),
                voicedMs: Value(voicedMs),
              ),
            );
      }
    }

    /// A meeting with [count] 30-second chunks on disk, finished unless
    /// [ended] says the lesson is still running.
    Future<int> seed(
      int count, {
      int voicedMs = 20000,
      bool ended = true,
    }) async {
      final meetingId = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: _t0,
          endedAt: ended
              ? Value(_t0.add(const Duration(hours: 1)))
              : const Value.absent(),
        ),
      );
      await addChunks(meetingId, count, voicedMs: voicedMs);
      return meetingId;
    }

    test('Gemini transcribes every window and the temp files go', () async {
      final meetingId = await seed(16); // 8 min → two 4-min windows
      transcriber.geminiResult = (call) => 'okno $call';
      await service().refine(meetingId);

      final windows = await db.refinedSegmentsDao.windows(meetingId);
      expect(windows.map((w) => w.status), everyElement(RefinedStatus.ready));
      expect(windows.map((w) => w.content), ['okno 1', 'okno 2']);
      expect(transcriber.whisperCalls, isEmpty);
      // The second window is told how the first one ended.
      expect(transcriber.contexts.last.previousText, 'okno 1');
      expect(dir.listSync().where((f) => p.basename(f.path).startsWith('refined_')), isEmpty);
    });

    test('no Gemini key plans short Whisper windows', () async {
      geminiKey = false;
      final meetingId = await seed(8); // 4 min → two 2-min windows
      await service().refine(meetingId);
      final windows = await db.refinedSegmentsDao.windows(meetingId);
      expect(windows, hasLength(2));
      expect(windows.map((w) => w.engine), everyElement(RefinedEngine.whisper));
      expect(transcriber.geminiCalls, isEmpty);
      expect(transcriber.whisperCalls, hasLength(2));
    });

    test('a permanent Gemini failure falls back to Whisper', () async {
      final meetingId = await seed(4);
      transcriber.geminiResult =
          (_) => const AiPermanentException('zablokováno');
      transcriber.whisperResult = (_) => 'z whisperu';
      await service().refine(meetingId);

      final w = (await db.refinedSegmentsDao.windows(meetingId)).single;
      expect(w.status, RefinedStatus.ready);
      expect(w.engine, RefinedEngine.whisper);
      expect(w.content, 'z whisperu');
      expect(transcriber.geminiCalls, hasLength(1));
    });

    test('transient failures are retried, then the window fails', () async {
      final meetingId = await seed(4);
      transcriber.geminiResult =
          (_) => const AiTransientException('429');
      transcriber.whisperResult =
          (_) => const SttTransientException('503');
      await service().refine(meetingId);

      final w = (await db.refinedSegmentsDao.windows(meetingId)).single;
      expect(w.status, RefinedStatus.failed);
      expect(w.error, contains('429'));
      expect(transcriber.geminiCalls, hasLength(2));
      expect(transcriber.whisperCalls, hasLength(2));

      transcriber.geminiResult = (_) => 'napodruhé';
      await service().retryWindow(w.id);
      final again = (await db.refinedSegmentsDao.windows(meetingId)).single;
      expect(again.status, RefinedStatus.ready);
      expect(again.content, 'napodruhé');
    });

    test('a window with no voiced audio is ready without a request', () async {
      final meetingId = await seed(4, voicedMs: 100);
      await service().refine(meetingId);
      final w = (await db.refinedSegmentsDao.windows(meetingId)).single;
      expect(w.status, RefinedStatus.ready);
      expect(w.content, '');
      expect(transcriber.geminiCalls, isEmpty);
    });

    test('missing audio fails the window', () async {
      final meetingId = await seed(4);
      for (final f in dir.listSync()) {
        f.deleteSync();
      }
      await service().refine(meetingId);
      final w = (await db.refinedSegmentsDao.windows(meetingId)).single;
      expect(w.status, RefinedStatus.failed);
      expect(transcriber.geminiCalls, isEmpty);
    });

    test('a meeting still recording is not refined', () async {
      final meetingId = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(title: 'Běží', createdAt: _t0),
      );
      await service().refine(meetingId);
      expect(await db.refinedSegmentsDao.windows(meetingId), isEmpty);
    });

    test('a lesson still running refines only its whole windows', () async {
      final meetingId = await seed(10, ended: false); // 5 min
      transcriber.geminiResult = (call) => 'okno $call';
      await service().refineWhileRecording(meetingId);

      // One 4-minute window; the 60 s recorded since is still being spoken.
      final windows = await db.refinedSegmentsDao.windows(meetingId);
      expect(windows, hasLength(1));
      expect(windows.single.endMs, 240000);
      expect(windows.single.content, 'okno 1');

      // Nothing new to close yet, so no second request.
      await service().refineWhileRecording(meetingId);
      expect(transcriber.geminiCalls, hasLength(1));
    });

    test('stopping keeps what the lesson already refined', () async {
      final meetingId = await seed(10, ended: false);
      transcriber.geminiResult = (call) => 'okno $call';
      await service().refineWhileRecording(meetingId);

      await addChunks(meetingId, 2, from: 10);
      await db.meetingsDao.markEnded(meetingId, _t0.add(const Duration(hours: 1)));
      await service().refine(meetingId);

      final windows = await db.refinedSegmentsDao.windows(meetingId);
      expect(windows.map((w) => w.content), ['okno 1', 'okno 2']);
      // The tail window starts where the finished one ended, so the first
      // four minutes are not paid for twice.
      expect(windows.last.startMs, 240000);
      expect(transcriber.geminiCalls, hasLength(2));
    });

    test('‚Přepsat znovu‘ plans the whole meeting again', () async {
      final meetingId = await seed(16); // 8 min → two 4-min windows
      transcriber.geminiResult = (call) => 'okno $call';
      await service().refine(meetingId);
      expect(transcriber.geminiCalls, hasLength(2));

      await service().refine(meetingId, force: true);
      final windows = await db.refinedSegmentsDao.windows(meetingId);
      expect(windows, hasLength(2));
      expect(windows.map((w) => w.content), ['okno 3', 'okno 4']);
    });

    test('resume picks up pending and interrupted windows', () async {
      final meetingId = await seed(8);
      await db.refinedSegmentsDao.replaceWindows(meetingId, [
        (startMs: 0, endMs: 120000, engine: RefinedEngine.gemini),
        (startMs: 120000, endMs: 240000, engine: RefinedEngine.gemini),
      ]);
      final first = (await db.refinedSegmentsDao.windows(meetingId)).first;
      await db.refinedSegmentsDao.markRunning(first.id);

      await service().resume();
      final windows = await db.refinedSegmentsDao.windows(meetingId);
      expect(windows.map((w) => w.status), everyElement(RefinedStatus.ready));
      expect(transcriber.geminiCalls, hasLength(2));
    });

    test('deleting a meeting removes its windows; orphans are swept', () async {
      final meetingId = await seed(4);
      await service().refine(meetingId);
      await db.meetingsDao.deleteMeeting(meetingId);
      expect(await db.refinedSegmentsDao.windows(meetingId), isEmpty);

      await db.refinedSegmentsDao.replaceWindows(99, [
        (startMs: 0, endMs: 1000, engine: RefinedEngine.whisper),
      ]);
      await db.meetingsDao.deleteOrphanRows();
      expect(await db.refinedSegmentsDao.windows(99), isEmpty);
    });
  });
}

List<int> _u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
List<int> _u16(int v) =>
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();
