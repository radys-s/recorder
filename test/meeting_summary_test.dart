import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/meetings_dao.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime(2026, 9, 18, 9);

  Future<int> seed(String title, List<double?> confidences) async {
    final meetingId = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(title: title, createdAt: now),
    );
    for (var i = 0; i < confidences.length; i++) {
      await db
          .into(db.transcriptSegments)
          .insert(
            TranscriptSegmentsCompanion.insert(
              meetingId: meetingId,
              sequence: i,
              startMs: i * 10000,
              endMs: (i + 1) * 10000,
              status: SegmentStatus.transcribed,
              localAudioPath: 'recordings/meeting_$meetingId/chunk_$i.wav',
              createdAt: now,
              confidence: Value(confidences[i]),
            ),
          );
    }
    return meetingId;
  }

  Future<MeetingSummary> summaryOf(int meetingId) async {
    final all = await db.meetingsDao.watchMeetingSummaries().first;
    return all.firstWhere((s) => s.meeting.id == meetingId);
  }

  test(
    'a lesson Whisper kept struggling with is marked as weak audio',
    () async {
      final id = await seed('Slabá', List.filled(10, -1.2));
      expect((await summaryOf(id)).weakAudio, isTrue);
    },
  );

  test('a clearly heard lesson says nothing about its audio', () async {
    final id = await seed('Dobrá', List.filled(10, -0.3));
    expect((await summaryOf(id)).weakAudio, isFalse);
  });

  test('one badly heard chunk is not the room', () async {
    // Below the threshold on average, but far too little evidence to tell the
    // student to move their phone.
    final id = await seed('Krátká', [-1.4, -1.4, -1.4]);
    final summary = await summaryOf(id);
    expect(summary.scoredCount, 3);
    expect(summary.weakAudio, isFalse);
  });

  test('segments from before scores were stored do not count', () async {
    final id = await seed('Stará', List.filled(10, null));
    final summary = await summaryOf(id);
    expect(summary.segmentCount, 10);
    expect(summary.scoredCount, 0);
    expect(summary.avgConfidence, isNull);
    expect(summary.weakAudio, isFalse);
  });
}
