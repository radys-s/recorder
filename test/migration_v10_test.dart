import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/refined_segments_table.dart';

/// The v9 schema exactly as a v9 build created it, so the upgrade runs against
/// what is really on the user's phone rather than against today's tables.
const _v9Schema = [
  'CREATE TABLE "meetings" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "title" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "ended_at" INTEGER NULL, "interrupted" INTEGER NOT NULL DEFAULT 0 CHECK ("interrupted" IN (0, 1)));',
  'CREATE TABLE "transcript_segments" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "meeting_id" INTEGER NOT NULL, "sequence" INTEGER NOT NULL, "start_ms" INTEGER NOT NULL, "end_ms" INTEGER NOT NULL, "content" TEXT NULL, "status" INTEGER NOT NULL, "local_audio_path" TEXT NOT NULL, "created_at" INTEGER NOT NULL);',
  'CREATE TABLE "upload_queue" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "segment_id" INTEGER NOT NULL, "meeting_id" INTEGER NOT NULL, "local_file_path" TEXT NOT NULL, "status" INTEGER NOT NULL, "attempt_count" INTEGER NOT NULL DEFAULT 0, "next_retry_at" INTEGER NULL, "last_error" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL);',
  'CREATE TABLE "preferences" ("id" INTEGER NOT NULL DEFAULT 0, "transcript_language" INTEGER NOT NULL DEFAULT 0, "notes_depth" INTEGER NOT NULL DEFAULT 1, "live_answers_enabled" INTEGER NOT NULL DEFAULT 0 CHECK ("live_answers_enabled" IN (0, 1)), "web_answers_enabled" INTEGER NOT NULL DEFAULT 0 CHECK ("web_answers_enabled" IN (0, 1)), "mic_sensitivity" INTEGER NOT NULL DEFAULT 1, PRIMARY KEY ("id"));',
  'CREATE TABLE "meeting_notes" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "meeting_id" INTEGER NOT NULL, "depth" INTEGER NOT NULL, "content" TEXT NULL, "model" TEXT NOT NULL, "status" INTEGER NOT NULL, "error" TEXT NULL, "created_at" INTEGER NOT NULL, UNIQUE ("meeting_id"));',
  'CREATE TABLE "answer_cards" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "meeting_id" INTEGER NOT NULL, "segment_id" INTEGER NOT NULL, "question" TEXT NOT NULL, "answer" TEXT NOT NULL, "basis" TEXT NOT NULL DEFAULT \'meeting\', "sources" TEXT NULL, "dismissed" INTEGER NOT NULL DEFAULT 0 CHECK ("dismissed" IN (0, 1)), "created_at" INTEGER NOT NULL);',
  'CREATE TABLE "note_folders" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "created_at" INTEGER NOT NULL);',
  'CREATE TABLE "saved_notes" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "title" TEXT NOT NULL, "content" TEXT NOT NULL, "folder_id" INTEGER NULL, "meeting_id" INTEGER NULL, "depth" INTEGER NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL);',
];

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  AppDatabase seededV9() => AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        for (final sql in _v9Schema) {
          raw.execute(sql);
        }
        raw.execute(
          "INSERT INTO note_folders (id, name, created_at) VALUES (3, 'Čeština', 1000)",
        );
        raw.execute(
          "INSERT INTO saved_notes (id, title, content, folder_id, meeting_id, depth, created_at, updated_at) VALUES (5, 'Máj', '- Mácha', 3, 9, 1, 1000, 1000)",
        );
        raw.execute(
          "INSERT INTO meetings (id, title, created_at, ended_at) VALUES (9, 'Hodina', 1000, 2000)",
        );
        raw.execute(
          "INSERT INTO answer_cards (meeting_id, segment_id, question, answer, created_at) VALUES (9, 1, 'Kdo?', 'Mácha', 1000)",
        );
        raw.execute(
          "INSERT INTO transcript_segments (meeting_id, sequence, start_ms, end_ms, content, status, local_audio_path, created_at) VALUES (9, 0, 0, 8000, 'Máj', 2, 'a.wav', 1000)",
        );
        raw.execute('INSERT INTO preferences (id) VALUES (0)');
        raw.execute('PRAGMA user_version = 9');
      },
    ),
  );

  test('v9 → v10 keeps folders, notes, meetings and answers', () async {
    final db = seededV9();
    addTearDown(db.close);

    final subject = await db.subjectsDao.subject(3);
    expect(subject!.name, 'Čeština');
    expect(subject.rules, isNull);
    expect(subject.colorIndex, 0);

    final note = await db.select(db.savedNotes).getSingle();
    expect(note.folderId, 3);
    expect(note.title, 'Máj');

    final meeting = await db.select(db.meetings).getSingle();
    expect(meeting.title, 'Hodina');
    expect(meeting.subjectId, isNull);

    final card = await db.select(db.answerCards).getSingle();
    expect(card.answer, 'Mácha');
    expect(card.detail, isNull);

    // v12 adds voiced_ms; old segments have none and skip the rate guard.
    final segment = await db.select(db.transcriptSegments).getSingle();
    expect(segment.content, 'Máj');
    expect(segment.voicedMs, isNull);

    final prefs = await db.preferencesDao.current();
    expect(prefs.globalRules, isNull);
    // v11 switches an existing install to automatic sensitivity once.
    expect(prefs.micSensitivity, MicSensitivity.auto);

    // The new tables exist and take rows.
    final cardId = await db.subjectsDao.createCard(
      subjectId: 3,
      title: 'Máj',
      content: 'Lyrickoepická báseň',
    );
    await db.subjectsDao.pinCards(9, [cardId]);
    expect(await db.subjectsDao.pinnedCardIds(9), [cardId]);
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            meetingId: 9,
            role: ChatRole.user,
            intent: ChatIntent.context,
            atMs: 0,
            status: ChatStatus.ready,
            createdAt: DateTime.now(),
          ),
        );
    // v13 adds the refined transcript.
    await db.refinedSegmentsDao.replaceWindows(9, [
      (startMs: 0, endMs: 8000, engine: RefinedEngine.gemini),
    ]);
    expect(await db.refinedSegmentsDao.meetingsWithPending(), [9]);
    // v14 adds card suggestions to the notes.
    await db.meetingNotesDao.markGenerating(9, NotesDepth.standard, 'm');
    await db.meetingNotesDao.markReady(9, 'Výpisky');
    await db.meetingNotesDao.setCardSuggestions(9, '[]');
    expect((await db.meetingNotesDao.forMeeting(9))!.cardSuggestions, '[]');
    // v15 adds the Gemini model override.
    await db.preferencesDao.setGeminiModelOverride('gemini-3-flash');
    expect(
      (await db.preferencesDao.current()).geminiModelOverride,
      'gemini-3-flash',
    );
    // v16 adds subject terms, the original text of a corrected segment and
    // the onboarding flag.
    await db.subjectsDao.addTerm(3, 'Proško', heard: 'prosko');
    expect((await db.subjectsDao.terms(3)).single.heard, 'prosko');
    final v16Segment = (await db.transcriptSegmentsDao.segmentsForMeeting(9))
        .single;
    await db.transcriptSegmentsDao.correctSegment(v16Segment.id, 'Máj!');
    expect(
      (await db.transcriptSegmentsDao.segmentById(v16Segment.id))!.rawContent,
      'Máj',
    );
    await db.preferencesDao.setOnboardingDismissed(true);
    expect((await db.preferencesDao.current()).onboardingDismissed, isTrue);
  });

  test('the upgraded schema matches a fresh v10 database', () async {
    final upgraded = seededV9();
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(upgraded.close);
    addTearDown(fresh.close);

    Future<Map<String, Set<String>>> shape(AppDatabase db) async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      return {
        for (final t in tables)
          t.read<String>('name'): {
            for (final c
                in await db
                    .customSelect(
                      'PRAGMA table_info("${t.read<String>('name')}")',
                    )
                    .get())
              '${c.read<String>('name')}:${c.read<String>('type')}:'
                  '${c.read<int>('notnull')}',
          },
      };
    }

    expect(await shape(upgraded), await shape(fresh));
  });
}
