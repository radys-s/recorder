import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/refined_segments_table.dart';
import 'package:recorder/data/db/tables/subject_terms_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/features/meeting_detail/transcript_fix.dart';
import 'package:recorder/features/meeting_detail/widgets/word_fix_sheet.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late int meeting;

  Future<int> segment(int seq, String text) =>
      db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: meeting,
          sequence: seq,
          startMs: seq * 8000,
          endMs: (seq + 1) * 8000,
          content: Value(text),
          status: SegmentStatus.transcribed,
          localAudioPath: 'a$seq.wav',
          createdAt: DateTime(2026),
        ),
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    meeting = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026)),
    );
  });
  tearDown(() => db.close());

  test('wordsOf keeps offsets and skips punctuation', () {
    final words = wordsOf('Viktorka, ta zpívala.');
    expect(words.map((w) => w.word), ['Viktorka', 'ta', 'zpívala']);
    expect(words[2].start, 13);
    expect(words[2].end, 20);
  });

  test('a fix runs through every segment and ready window', () async {
    final a = await segment(0, 'Pak přišel viktor ka.');
    final b = await segment(1, 'Nic.');
    final c = await segment(2, 'A viktor ka zpívala.');
    await db.refinedSegmentsDao.replaceWindows(meeting, [
      (startMs: 0, endMs: 24000, engine: RefinedEngine.whisper),
      (startMs: 24000, endMs: 30000, engine: RefinedEngine.whisper),
    ]);
    final windows = await db.refinedSegmentsDao.windows(meeting);
    await db.refinedSegmentsDao.markReady(
      windows[0].id,
      'Přišel viktor ka.',
      RefinedEngine.whisper,
    );

    final changed = await fixWordInMeeting(
      db,
      meetingId: meeting,
      heard: 'viktor ka',
      term: 'Viktorka',
      remember: true,
    );

    expect(changed, 3);
    final dao = db.transcriptSegmentsDao;
    expect((await dao.segmentById(a))!.content, 'Pak přišel Viktorka.');
    expect((await dao.segmentById(a))!.rawContent, 'Pak přišel viktor ka.');
    expect((await dao.segmentById(b))!.rawContent, isNull);
    expect((await dao.segmentById(c))!.content, 'A Viktorka zpívala.');
    final w = await db.refinedSegmentsDao.windows(meeting);
    expect(w[0].content, 'Přišel Viktorka.');
    expect(w[1].content, isNull);
  });

  test('remember stores a correction term for the lesson subject', () async {
    final subject = await db.savedNotesDao.createFolder('Čeština');
    await db.subjectsDao.setMeetingSubject(meeting, subject);
    await segment(0, 'Přišel prosko a pak Prosko odešel.');

    await fixWordInMeeting(
      db,
      meetingId: meeting,
      heard: 'viktor ka',
      term: 'Viktorka',
      remember: true,
    );
    await fixWordInMeeting(
      db,
      meetingId: meeting,
      heard: 'prosko',
      term: 'Proško',
      remember: true,
    );

    final terms = await db.subjectsDao.terms(subject);
    expect(
      terms.map((t) => (t.term, t.heard, t.source)),
      containsAll([
        ('Viktorka', 'viktor ka', TermSource.correction),
        ('Proško', 'prosko', TermSource.correction),
      ]),
    );
    final row = (await db.transcriptSegmentsDao.segmentsForMeeting(meeting))
        .single;
    expect(row.content, 'Přišel Proško a pak Proško odešel.');
  });

  test('without a subject nothing is remembered', () async {
    await segment(0, 'prosko');
    final changed = await fixWordInMeeting(
      db,
      meetingId: meeting,
      heard: 'prosko',
      term: 'Proško',
      remember: true,
    );
    expect(changed, 1);
    expect(await db.select(db.subjectTerms).get(), isEmpty);
  });

  testWidgets('the sheet picks adjacent words and restores the original', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await segment(0, 'A viktor ka zpívala.');
    });
    var restored = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: WordFixSheet(
              meetingId: meeting,
              text: 'A viktor ka zpívala.',
              original: 'A viktor ka zpivala.',
              onRestore: () async => restored = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Původně slyšeno'), findsOneWidget);
    await tester.tap(find.text('viktor'));
    await tester.pump();
    await tester.tap(find.text('ka'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'viktor ka');

    await tester.tap(find.text('Vrátit původní'));
    await tester.pump();
    expect(restored, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
