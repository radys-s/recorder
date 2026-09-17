import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../data/db/tables/chat_messages_table.dart';
import '../data/db/tables/preferences_table.dart';
import '../data/db/tables/transcript_segments_table.dart';

/// Demo data for the web preview. Never used by the app itself.
Future<({int lesson, int? recording})> seedDemo(
  AppDatabase db, {
  required bool recording,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final cestina = await db.savedNotesDao.createFolder('Čeština');
  final dejepis = await db.savedNotesDao.createFolder('Dějepis');
  await db.subjectsDao.setSubjectColor(dejepis, 3);
  final minute = now.hour * 60 + now.minute;
  await db.subjectsDao.addSlot(
    subjectId: cestina,
    weekday: now.weekday,
    startMinute: (minute - 10).clamp(0, 1300),
    endMinute: (minute + 35).clamp(60, 1439),
  );
  await db.subjectsDao.addSlot(
    subjectId: dejepis,
    weekday: now.weekday,
    startMinute: (minute + 55).clamp(0, 1380),
    endMinute: (minute + 100).clamp(60, 1439),
  );

  final babicka = await db.subjectsDao.createCard(
    subjectId: cestina,
    title: 'Babička',
    content:
        'Božena Němcová, 1855. Próza, obrazy z venkovského života. '
        'Postavy: babička, Proško, Viktorka, kněžna.',
  );
  await db.subjectsDao.createCard(
    subjectId: cestina,
    title: 'Máj',
    content: 'Karel Hynek Mácha, 1836. Lyrickoepická báseň, romantismus.',
  );
  await db.subjectsDao.addTerm(cestina, 'Proško', heard: 'prosko');
  await db.subjectsDao.addTerm(cestina, 'realismus');

  final lesson = await db.meetingsDao.insertMeeting(
    MeetingsCompanion.insert(
      title: 'Hodina ${today.day}.${today.month}. 8:00',
      createdAt: today.add(const Duration(hours: 8)),
      endedAt: Value(today.add(const Duration(hours: 8, minutes: 12))),
      subjectId: Value(cestina),
    ),
  );
  await db.subjectsDao.pinCards(lesson, [babicka]);
  const lines = [
    'Dobrý den, dnes budeme pokračovat v Babičce od Boženy Němcové.',
    'Minule jsme skončili u kapitoly, kde přišel viktor ka k splavu.',
    'Zkuste si říct, jaký literární druh ta kniha je.',
    'Je to próza, přesněji obrazy ze života na venkově.',
    'Proško pracoval u knížete jako myslivec.',
    'Do příští hodiny si přečtěte další dvě kapitoly.',
  ];
  var firstSegment = 0;
  for (var i = 0; i < lines.length; i++) {
    final id = await db.transcriptSegmentsDao.insertSegment(
      TranscriptSegmentsCompanion.insert(
        meetingId: lesson,
        sequence: i,
        startMs: i * 20000,
        endMs: (i + 1) * 20000,
        content: Value(lines[i]),
        rawContent: Value(
          i == 4 ? 'Prosko pracoval u knížete jako myslivec.' : null,
        ),
        // One chunk the recognizer barely believed, shown greyed.
        confidence: Value(i == 1 ? -1.1 : -0.3),
        status: SegmentStatus.transcribed,
        localAudioPath: 'recordings/meeting_$lesson/chunk_$i.wav',
        createdAt: today.add(Duration(hours: 8, seconds: i * 20)),
      ),
    );
    if (i == 0) firstSegment = id;
  }
  await db.answerCardsDao.insertCard(
    AnswerCardsCompanion.insert(
      meetingId: lesson,
      segmentId: firstSegment + 2,
      question: 'Jaký literární druh je Babička?',
      answer: 'Próza — obrazy z venkovského života',
      detail: const Value(
        'Babička je prozaické dílo, podle autorky obrazy venkovského života.',
      ),
      basis: const Value('card'),
      cardId: Value(babicka),
      createdAt: today.add(const Duration(hours: 8, minutes: 1)),
    ),
  );
  await db.chatMessagesDao.addUserMessage(
    meetingId: lesson,
    text: 'Čteme úryvek o Viktorce u splavu',
    intent: ChatIntent.context,
    atMs: 15000,
  );
  await db.chatMessagesDao.addImportant(
    meetingId: lesson,
    atMs: 100000,
    note: 'Dvě kapitoly na příště',
  );
  await db.meetingNotesDao.markGenerating(lesson, NotesDepth.standard, 'demo');
  await db.meetingNotesDao.markReady(
    lesson,
    'Téma:\n- Babička, Božena Němcová\n\nKlíčové pojmy:\n'
    '- próza – souvislý text, ne verše\n\nCo si zapamatovat:\n'
    '- Babička jsou obrazy venkovského života\n\nDomácí úkol:\n'
    '- přečíst další dvě kapitoly',
  );

  final meeting = await db.meetingsDao.insertMeeting(
    MeetingsCompanion.insert(
      title: 'Porada týmu',
      createdAt: today.subtract(const Duration(hours: 10)),
      endedAt: Value(today.subtract(const Duration(hours: 9))),
    ),
  );
  await db.transcriptSegmentsDao.insertSegment(
    TranscriptSegmentsCompanion.insert(
      meetingId: meeting,
      sequence: 0,
      startMs: 0,
      endMs: 20000,
      content: const Value('Rozpočet schválíme ve čtvrtek.'),
      status: SegmentStatus.transcribed,
      localAudioPath: 'recordings/meeting_$meeting/chunk_0.wav',
      createdAt: today.subtract(const Duration(hours: 10)),
    ),
  );

  await db.savedNotesDao.saveNote(
    title: 'Babička — výpisky',
    content: '- Božena Němcová\n- obrazy venkovského života',
    folderId: cestina,
    meetingId: lesson,
    depth: NotesDepth.standard,
  );
  await db.savedNotesDao.saveNote(
    title: 'Třicetiletá válka',
    content: '- 1618–1648\n- defenestrace',
    folderId: dejepis,
  );

  int? live;
  if (recording) {
    live = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: 'Hodina teď',
        createdAt: now,
        subjectId: Value(cestina),
      ),
    );
    await db.transcriptSegmentsDao.insertSegment(
      TranscriptSegmentsCompanion.insert(
        meetingId: live,
        sequence: 0,
        startMs: 0,
        endMs: 12000,
        content: const Value('Otevřete si čítanku na straně čtyřicet.'),
        status: SegmentStatus.transcribed,
        localAudioPath: 'recordings/meeting_$live/chunk_0.wav',
        createdAt: now,
      ),
    );
  }
  return (lesson: lesson, recording: live);
}
